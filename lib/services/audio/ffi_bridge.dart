import 'dart:ffi'; // For FFI
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

// --- FFI Typedefs ---

// void* createAnalyzer(int sampleRate, int bufferSize)
typedef CreateAnalyzerC =
    Pointer<Void> Function(Int32 sampleRate, Int32 bufferSize);
typedef CreateAnalyzerDart =
    Pointer<Void> Function(int sampleRate, int bufferSize);

// float processAudioBlock(void* analyzerInstance, float* inputBuffer, int bufferSize)
typedef ProcessAudioBlockC =
    Float Function(
      Pointer<Void> analyzerInstance,
      Pointer<Float> inputBuffer,
      Int32 bufferSize,
    );
typedef ProcessAudioBlockDart =
    double Function(
      Pointer<Void> analyzerInstance,
      Pointer<Float> inputBuffer,
      int bufferSize,
    );

// void destroyAnalyzer(void* analyzerInstance)
typedef DestroyAnalyzerC = Void Function(Pointer<Void> analyzerInstance);
typedef DestroyAnalyzerDart = void Function(Pointer<Void> analyzerInstance);

class NativeAudioAnalyzer {
  late DynamicLibrary _lib;
  late CreateAnalyzerDart _createAnalyzer;
  late ProcessAudioBlockDart _processAudioBlock;
  late DestroyAnalyzerDart _destroyAnalyzer;

  Pointer<Void>? _analyzerHandle;
  Pointer<Float>? _inputBuffer;
  int _bufferSize = 0;

  NativeAudioAnalyzer() {
    _loadLibrary();
    _lookupFunctions();
  }

  void _loadLibrary() {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported yet (requires WASM implementation).',
      );
    }
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libaudio_analyzer.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('audio_analyzer.dll');
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  void _lookupFunctions() {
    _createAnalyzer = _lib.lookupFunction<CreateAnalyzerC, CreateAnalyzerDart>(
      'createAnalyzer',
    );
    _processAudioBlock = _lib
        .lookupFunction<ProcessAudioBlockC, ProcessAudioBlockDart>(
          'processAudioBlock',
        );
    _destroyAnalyzer = _lib
        .lookupFunction<DestroyAnalyzerC, DestroyAnalyzerDart>(
          'destroyAnalyzer',
        );
  }

  /// Initializes the native analyzer.
  /// [sampleRate] e.g. 44100
  /// [bufferSize] e.g. 512. Must match the buffer size you pass to process().
  void init(int sampleRate, int bufferSize) {
    if (_analyzerHandle != null) {
      dispose();
    }
    _analyzerHandle = _createAnalyzer(sampleRate, bufferSize);
    _bufferSize = bufferSize;
    // Allocate the input buffer once to avoid re-allocating every frame
    _inputBuffer = calloc<Float>(bufferSize);
  }

  /// Processes a single block of audio data.
  /// [data] must be a list of floats (samples).
  /// Returns the detected frequency in Hz, or 0.0 if silent/uncertain.
  double processBlock(List<double> data) {
    if (_analyzerHandle == null || _inputBuffer == null) {
      throw StateError('Analyzer not initialized. Call init() first.');
    } // Optimized: Assuming data.length <= _bufferSize.
    // Copy Dart list to native heap
    for (int i = 0; i < data.length && i < _bufferSize; i++) {
      _inputBuffer![i] = data[i];
    }
    // Zero fill the rest if data is smaller than buffer
    if (data.length < _bufferSize) {
      for (int i = data.length; i < _bufferSize; i++) {
        _inputBuffer![i] = 0.0;
      }
    }

    return _processAudioBlock(_analyzerHandle!, _inputBuffer!, _bufferSize);
  }

  /// Cleans up native resources.
  void dispose() {
    if (_analyzerHandle != null) {
      _destroyAnalyzer(_analyzerHandle!);
      _analyzerHandle = null;
    }
    if (_inputBuffer != null) {
      calloc.free(_inputBuffer!);
      _inputBuffer = null;
    }
  }
}
