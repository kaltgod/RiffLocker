import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ffi_bridge.dart';
import 'dart_pitch_detector.dart';

class TunerResult {
  final double frequency;
  final String noteName;
  final double cents; // Deviation from the perfect note (-50 to +50)
  final bool isSilent;

  TunerResult({
    required this.frequency,
    required this.noteName,
    required this.cents,
    this.isSilent = false,
  });

  static TunerResult silent() =>
      TunerResult(frequency: 0, noteName: "-", cents: 0, isSilent: true);
}

class TunerService {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();

  // Native analyzer (Android/Windows) or Dart fallback (iOS)
  NativeAudioAnalyzer? _nativeAnalyzer;
  DartPitchDetector? _dartAnalyzer;
  bool _useNative = true;

  final StreamController<TunerResult> _resultController =
      StreamController<TunerResult>.broadcast();
  Stream<TunerResult> get resultStream => _resultController.stream;

  bool _isRecording = false;

  // Audio configuration
  static const int _sampleRate = 44100;
  static const int _bufferSize = 2048;

  // Internal buffer to accumulate samples
  List<double> _accumulationBuffer = [];

  Future<void> init() async {
    // Initialize audio capture plugin
    await _audioCapture.init();

    // Try native analyzer first, fallback to Dart on iOS
    if (Platform.isIOS) {
      // iOS: Use Dart fallback (native lib not compiled)
      _useNative = false;
      _dartAnalyzer = DartPitchDetector(
        sampleRate: _sampleRate,
        bufferSize: _bufferSize,
      );
      debugPrint('TunerService: Using Dart pitch detector (iOS fallback)');
    } else {
      // Android/Windows: Use native FFI
      try {
        _nativeAnalyzer = NativeAudioAnalyzer();
        _nativeAnalyzer!.init(_sampleRate, _bufferSize);
        _useNative = true;
        debugPrint('TunerService: Using native FFI analyzer');
      } catch (e) {
        // Fallback to Dart if native fails
        debugPrint(
          'TunerService: Native init failed ($e), using Dart fallback',
        );
        _useNative = false;
        _dartAnalyzer = DartPitchDetector(
          sampleRate: _sampleRate,
          bufferSize: _bufferSize,
        );
      }
    }
  }

  Future<void> start() async {
    if (_isRecording) return;

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }

    _accumulationBuffer = [];

    await _audioCapture.start(
      _onAudioCallback,
      _onErrorCallback,
      sampleRate: _sampleRate,
      bufferSize: _bufferSize,
    );

    _isRecording = true;
  }

  Future<void> stop() async {
    if (!_isRecording) return;
    await _audioCapture.stop();
    _isRecording = false;
    _resultController.add(TunerResult.silent());
  }

  void dispose() {
    stop();
    _nativeAnalyzer?.dispose();
    _resultController.close();
  }

  void _onAudioCallback(dynamic audioData) {
    List<double> samples;
    if (audioData is Float32List) {
      samples = audioData;
    } else if (audioData is List<double>) {
      samples = audioData;
    } else {
      debugPrint("Unknown audio data type: ${audioData.runtimeType}");
      return;
    }

    _accumulationBuffer.addAll(samples);

    while (_accumulationBuffer.length >= _bufferSize) {
      var chunk = _accumulationBuffer.sublist(0, _bufferSize);
      _accumulationBuffer = _accumulationBuffer.sublist(_bufferSize);

      // RMS Gate
      double sumSquare = 0;
      for (var s in chunk) {
        sumSquare += s * s;
      }
      double rms = sqrt(sumSquare / chunk.length);

      const double rmsThreshold = 0.002;

      if (rms < rmsThreshold) {
        _resultController.add(TunerResult.silent());
        continue;
      }

      // Process via native or Dart
      double frequency;
      if (_useNative && _nativeAnalyzer != null) {
        frequency = _nativeAnalyzer!.processBlock(chunk);
      } else if (_dartAnalyzer != null) {
        frequency = _dartAnalyzer!.processBlock(chunk);
      } else {
        continue;
      }

      // Frequency Range Filter
      if (frequency < 70 || frequency > 1200) {
        _resultController.add(TunerResult.silent());
        continue;
      }

      // Stability Filter
      _frequencyHistory.add(frequency);
      if (_frequencyHistory.length > 3) {
        _frequencyHistory.removeAt(0);
      }

      if (_isSignalStable()) {
        double avgFreq =
            _frequencyHistory.reduce((a, b) => a + b) /
            _frequencyHistory.length;
        _resultController.add(_calculatePitch(avgFreq));
      } else {
        _resultController.add(TunerResult.silent());
      }
    }
  }

  final List<double> _frequencyHistory = [];

  bool _isSignalStable() {
    if (_frequencyHistory.length < 3) return false;
    if (_frequencyHistory.any((f) => f <= 0)) return false;

    double first = _frequencyHistory.first;
    double last = _frequencyHistory.last;

    double threshold = first * 0.10;

    if ((first - last).abs() > threshold) return false;
    if ((first - _frequencyHistory[1]).abs() > threshold) return false;

    return true;
  }

  void _onErrorCallback(Object error, StackTrace? stackTrace) {
    debugPrint("Audio Capture Error: $error");
  }

  final List<String> _noteNames = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
  ];

  TunerResult _calculatePitch(double frequency) {
    if (frequency < 20) return TunerResult.silent();

    double pitchMidi = 69 + 12 * (log(frequency / 440.0) / ln2);

    int roundedMidi = pitchMidi.round();
    double cents = (pitchMidi - roundedMidi) * 100;

    int noteIndex = roundedMidi % 12;
    int octave = (roundedMidi / 12).floor() - 1;

    String noteName = "${_noteNames[noteIndex]}$octave";

    return TunerResult(
      frequency: frequency,
      noteName: noteName,
      cents: cents,
      isSilent: false,
    );
  }
}
