import 'dart:math';

/// Pure Dart pitch detection using YIN algorithm.
/// Matches the native C++ Aubio YIN implementation as closely as possible.
/// Reference: "YIN, a fundamental frequency estimator for speech and music"
/// by A. de Cheveigné and H. Kawahara (2002)
class DartPitchDetector {
  final int sampleRate;
  final int bufferSize;

  // YIN parameters (matching Aubio defaults)
  static const double _yinThreshold = 0.15; // Aubio default threshold
  static const double _confidenceThreshold = 0.6; // Match C++ implementation

  // Frequency detection range (guitar: ~70Hz to ~1200Hz)
  late final int _minTau;
  late final int _maxTau;

  // Preallocated buffers for YIN algorithm
  late final List<double> _yinBuffer;

  DartPitchDetector({required this.sampleRate, required this.bufferSize}) {
    // Calculate tau range from frequency range
    // tau = sampleRate / frequency
    _minTau = (sampleRate / 1200).floor(); // ~1200 Hz max
    _maxTau = (sampleRate / 70).floor(); // ~70 Hz min

    // YIN buffer size is half the window size
    // Window size = bufferSize (we use the input buffer directly)
    _yinBuffer = List.filled(bufferSize ~/ 2, 0.0);
  }

  /// Process audio buffer and return detected frequency in Hz.
  /// Returns 0.0 if no pitch detected or confidence too low.
  double processBlock(List<double> samples) {
    if (samples.length < bufferSize) {
      return 0.0;
    }

    // Step 1: Calculate difference function
    _differenceFunction(samples);

    // Step 2: Cumulative mean normalized difference function
    _cumulativeMeanNormalizedDifference();

    // Step 3: Absolute threshold
    int tau = _absoluteThreshold();

    if (tau == -1) {
      return 0.0; // No pitch detected
    }

    // Step 4: Parabolic interpolation for better accuracy
    double betterTau = _parabolicInterpolation(tau);

    // Step 5: Calculate confidence
    double confidence = 1.0 - _yinBuffer[tau];

    // Match C++ confidence threshold
    if (confidence < _confidenceThreshold) {
      return 0.0;
    }

    // Convert tau to frequency
    double frequency = sampleRate / betterTau;

    // Sanity check frequency range
    if (frequency < 70 || frequency > 1200) {
      return 0.0;
    }

    return frequency;
  }

  /// Step 1: Difference function d(τ)
  /// d(τ) = Σ (x[j] - x[j+τ])²
  void _differenceFunction(List<double> samples) {
    int halfLen = _yinBuffer.length;

    for (int tau = 0; tau < halfLen; tau++) {
      double sum = 0.0;

      for (int j = 0; j < halfLen; j++) {
        double diff = samples[j] - samples[j + tau];
        sum += diff * diff;
      }

      _yinBuffer[tau] = sum;
    }
  }

  /// Step 2: Cumulative mean normalized difference function d'(τ)
  /// d'(τ) = d(τ) / [(1/τ) * Σ d(k)] for τ > 0
  /// d'(0) = 1
  void _cumulativeMeanNormalizedDifference() {
    _yinBuffer[0] = 1.0;

    double runningSum = 0.0;

    for (int tau = 1; tau < _yinBuffer.length; tau++) {
      runningSum += _yinBuffer[tau];

      if (runningSum > 0) {
        _yinBuffer[tau] = _yinBuffer[tau] * tau / runningSum;
      } else {
        _yinBuffer[tau] = 1.0;
      }
    }
  }

  /// Step 3: Absolute threshold
  /// Find the smallest τ where d'(τ) < threshold
  int _absoluteThreshold() {
    int tauEstimate = -1;

    // Start from minTau to avoid very high frequencies
    for (
      int tau = max(_minTau, 2);
      tau < min(_maxTau, _yinBuffer.length);
      tau++
    ) {
      if (_yinBuffer[tau] < _yinThreshold) {
        // Find the local minimum
        while (tau + 1 < _yinBuffer.length &&
            _yinBuffer[tau + 1] < _yinBuffer[tau]) {
          tau++;
        }
        tauEstimate = tau;
        break;
      }
    }

    // If no value below threshold found, search for global minimum
    if (tauEstimate == -1) {
      double minVal = double.infinity;
      for (
        int tau = max(_minTau, 2);
        tau < min(_maxTau, _yinBuffer.length);
        tau++
      ) {
        if (_yinBuffer[tau] < minVal) {
          minVal = _yinBuffer[tau];
          tauEstimate = tau;
        }
      }

      // Only accept if reasonably low
      if (minVal > 0.5) {
        return -1;
      }
    }

    return tauEstimate;
  }

  /// Step 4: Parabolic interpolation for sub-sample accuracy
  double _parabolicInterpolation(int tau) {
    if (tau < 1 || tau >= _yinBuffer.length - 1) {
      return tau.toDouble();
    }

    double s0 = _yinBuffer[tau - 1];
    double s1 = _yinBuffer[tau];
    double s2 = _yinBuffer[tau + 1];

    // Parabolic interpolation formula
    double adjustment = (s2 - s0) / (2 * (2 * s1 - s0 - s2));

    if (adjustment.isNaN || adjustment.isInfinite) {
      return tau.toDouble();
    }

    return tau + adjustment;
  }
}
