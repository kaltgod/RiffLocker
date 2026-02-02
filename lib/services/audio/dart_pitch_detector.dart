import 'dart:math';

/// Pure Dart pitch detection using autocorrelation algorithm.
/// Used as fallback when native FFI is unavailable (e.g., iOS).
class DartPitchDetector {
  final int sampleRate;
  final int bufferSize;

  // Frequency detection range (guitar: ~70Hz to ~1200Hz)
  late final int _minPeriod;
  late final int _maxPeriod;

  DartPitchDetector({required this.sampleRate, required this.bufferSize}) {
    // Calculate period range from frequency range
    _minPeriod = (sampleRate / 1200).floor(); // ~1200 Hz max
    _maxPeriod = (sampleRate / 70).floor(); // ~70 Hz min
  }

  /// Process audio buffer and return detected frequency in Hz.
  /// Returns 0.0 if no pitch detected or signal too weak.
  double processBlock(List<double> samples) {
    if (samples.length < _maxPeriod * 2) {
      return 0.0; // Not enough samples
    }

    // 1. Calculate RMS to check if signal is strong enough
    double sumSquare = 0;
    for (var s in samples) {
      sumSquare += s * s;
    }
    double rms = sqrt(sumSquare / samples.length);

    if (rms < 0.01) {
      return 0.0; // Signal too weak
    }

    // 2. Normalize samples
    List<double> normalized = samples.map((s) => s / rms).toList();

    // 3. Autocorrelation with peak detection
    double bestCorrelation = 0;
    int bestPeriod = 0;

    for (
      int period = _minPeriod;
      period <= _maxPeriod && period < normalized.length ~/ 2;
      period++
    ) {
      double correlation = _autocorrelate(normalized, period);

      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestPeriod = period;
      }
    }

    // 4. Check if correlation is strong enough
    if (bestCorrelation < 0.8 || bestPeriod == 0) {
      return 0.0; // No clear pitch detected
    }

    // 5. Parabolic interpolation for sub-sample accuracy
    double refinedPeriod = _parabolicInterpolation(normalized, bestPeriod);

    // 6. Convert period to frequency
    double frequency = sampleRate / refinedPeriod;

    return frequency;
  }

  /// Calculate normalized autocorrelation at given lag
  double _autocorrelate(List<double> samples, int lag) {
    double sum = 0;
    double sumA = 0;
    double sumB = 0;

    int n = samples.length - lag;

    for (int i = 0; i < n; i++) {
      double a = samples[i];
      double b = samples[i + lag];
      sum += a * b;
      sumA += a * a;
      sumB += b * b;
    }

    double denominator = sqrt(sumA * sumB);
    if (denominator < 0.0001) return 0;

    return sum / denominator;
  }

  /// Parabolic interpolation for better accuracy
  double _parabolicInterpolation(List<double> samples, int period) {
    if (period <= _minPeriod || period >= _maxPeriod - 1) {
      return period.toDouble();
    }

    double y0 = _autocorrelate(samples, period - 1);
    double y1 = _autocorrelate(samples, period);
    double y2 = _autocorrelate(samples, period + 1);

    double denominator = 2 * (2 * y1 - y0 - y2);
    if (denominator.abs() < 0.0001) {
      return period.toDouble();
    }

    double delta = (y0 - y2) / denominator;

    return period + delta;
  }
}
