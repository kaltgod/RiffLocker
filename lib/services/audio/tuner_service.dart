import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ffi_bridge.dart';

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
  final NativeAudioAnalyzer _analyzer = NativeAudioAnalyzer();

  final StreamController<TunerResult> _resultController =
      StreamController<TunerResult>.broadcast();
  Stream<TunerResult> get resultStream => _resultController.stream;

  bool _isRecording = false;

  // Audio configuration
  // Note: flutter_audio_capture usually gives us what the HW supports,
  // but we try to ask for standard settings.
  static const int _sampleRate = 44100;
  static const int _bufferSize =
      2048; // Analyzer block size (latency vs accuracy trade-off)

  // Internal buffer to accumulate samples if the callback gives us small chunks
  List<double> _accumulationBuffer = [];

  Future<void> init() async {
    // Initialize audio capture plugin
    await _audioCapture.init();
    try {
      _analyzer.init(_sampleRate, _bufferSize);
    } catch (e) {
      debugPrint("Error initializing NativeAudioAnalyzer: $e");
    }
  }

  Future<void> start() async {
    if (_isRecording) return;

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }

    _accumulationBuffer = [];

    // Start capturing
    // Note: listener returns Float32 input
    await _audioCapture.start(
      _onAudioCallback,
      _onErrorCallback,
      sampleRate: _sampleRate,
      bufferSize: _bufferSize, // This is a request not guarantee
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
    _analyzer.dispose();
    _resultController.close();
  }

  void _onAudioCallback(dynamic audioData) {
    // flutter_audio_capture passes Float32List (if handled correctly) or List<double>
    List<double> samples;
    if (audioData is Float32List) {
      samples = audioData;
    } else if (audioData is List<double>) {
      samples = audioData;
    } else {
      debugPrint("Unknown audio data type: ${audioData.runtimeType}");
      return;
    }

    // Accumulate samples
    _accumulationBuffer.addAll(samples);

    // Process when we have enough data
    while (_accumulationBuffer.length >= _bufferSize) {
      // Take a chunk
      var chunk = _accumulationBuffer.sublist(0, _bufferSize);
      _accumulationBuffer = _accumulationBuffer.sublist(_bufferSize);

      // 1. RMS Gate (Software Silence Threshold)
      // Calculate RMS for this chunk specifically
      double sumSquare = 0;
      for (var s in chunk) {
        sumSquare += s * s;
      }
      double rms = sqrt(sumSquare / chunk.length);

      // Adjust this value to filter background noise.
      // 0.001 is roughly -60dB. 0.002 is roughly -54dB.
      const double rmsThreshold = 0.002;

      if (rms < rmsThreshold) {
        _resultController.add(TunerResult.silent());
        continue;
      }

      // Process via FFI
      double frequency = _analyzer.processBlock(chunk);

      // 2. Frequency Range Filter (Guitar Specific)
      // Standard tuning: E2 (82Hz) to E4 (330Hz).
      // Allow margins: Drop D (73Hz) to 24th fret High E (~1300Hz).
      // Anything outside this is likely noise/harmonics.
      if (frequency < 70 || frequency > 1200) {
        // Ignore out of range frequencies
        _resultController.add(TunerResult.silent());
        continue;
      }

      // 3. Stability Filter
      _frequencyHistory.add(frequency);
      if (_frequencyHistory.length > 3) {
        _frequencyHistory.removeAt(0);
      }

      if (_isSignalStable()) {
        // Use median or average
        double avgFreq =
            _frequencyHistory.reduce((a, b) => a + b) /
            _frequencyHistory.length;
        _resultController.add(_calculatePitch(avgFreq));
      } else {
        _resultController.add(TunerResult.silent());
      }
    }
  }

  // History for stability check
  final List<double> _frequencyHistory = [];

  bool _isSignalStable() {
    if (_frequencyHistory.length < 3) return false;
    // ... same logic
    if (_frequencyHistory.any((f) => f <= 0)) return false;

    double first = _frequencyHistory.first;
    double last = _frequencyHistory.last;

    // Allow bigger deviation (e.g. 10%) because "attack" phase of a string can go sharp
    double threshold = first * 0.10;

    if ((first - last).abs() > threshold) return false;
    if ((first - _frequencyHistory[1]).abs() > threshold) return false;

    return true;
  }

  void _onErrorCallback(Object error, StackTrace? stackTrace) {
    debugPrint("Audio Capture Error: $error");
  }

  // --- Music Theory Util ---

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
    if (frequency < 20) return TunerResult.silent(); // Filter subsonic

    // A4 = 440Hz
    // MIDI Note Number equation: m = 69 + 12 * log2(f / 440)
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
