import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/common/providers/locale_provider.dart';
import '../../services/audio/tuner_service.dart';

class PrecisionTuner extends ConsumerWidget {
  final TunerResult result;

  const PrecisionTuner({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNoteDisplay(result),
          const SizedBox(height: 50),
          _buildGauge(result),
          const SizedBox(height: 20),
          Text(
            result.isSilent
                ? context.tr('listening', ref)
                : "${result.frequency.toStringAsFixed(1)} Hz",
            style: GoogleFonts.robotoMono(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteDisplay(TunerResult result) {
    Color color = Colors.grey;
    if (!result.isSilent) {
      if (result.cents.abs() < 5) {
        color = Colors.greenAccent; // In tune
      } else {
        color = Colors.redAccent;
      }
    }

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        result.noteName,
        style: GoogleFonts.outfit(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildGauge(TunerResult result) {
    // Gauge range: -50 cents to +50 cents
    double percent = 0.0;
    if (!result.isSilent) {
      percent = (result.cents / 50.0).clamp(-1.0, 1.0);
    }

    return SizedBox(
      width: 300,
      height: 50,
      child: CustomPaint(
        painter: GaugePainter(percent: percent, isSilent: result.isSilent),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double percent; // -1 to 1
  final bool isSilent;

  GaugePainter({required this.percent, required this.isSilent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final Paint linePaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw ticks
    for (int i = -5; i <= 5; i++) {
      double x = w / 2 + (i / 5.0) * (w / 2);
      double height = (i == 0) ? 20 : 10;
      canvas.drawLine(
        Offset(x, h / 2 - height / 2),
        Offset(x, h / 2 + height / 2),
        linePaint,
      );
    }

    if (!isSilent) {
      // Draw needle/indicator
      final Paint indicatorPaint = Paint()
        ..color = (percent.abs() < 0.1) ? Colors.greenAccent : Colors.redAccent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      double needleX = w / 2 + percent * (w / 2);
      canvas.drawLine(Offset(needleX, 0), Offset(needleX, h), indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(GaugePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.isSilent != isSilent;
  }
}
