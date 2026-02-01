import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/common/providers/locale_provider.dart';
import '../../services/audio/tuner_service.dart';

class AutoTuner extends ConsumerStatefulWidget {
  final TunerResult result;

  const AutoTuner({super.key, required this.result});

  @override
  ConsumerState<AutoTuner> createState() => _AutoTunerState();
}

class _AutoTunerState extends ConsumerState<AutoTuner> {
  // Track which strings have been tuned (stay green)
  final Set<int> _tunedStrings = {};

  static const List<_GuitarString> strings = [
    _GuitarString(name: 'Ми', nameEn: 'E', frequency: 82.41, index: 0),
    _GuitarString(name: 'Ля', nameEn: 'A', frequency: 110.00, index: 1),
    _GuitarString(name: 'Ре', nameEn: 'D', frequency: 146.83, index: 2),
    _GuitarString(name: 'Соль', nameEn: 'G', frequency: 196.00, index: 3),
    _GuitarString(name: 'Си', nameEn: 'B', frequency: 246.94, index: 4),
    _GuitarString(name: 'Ми', nameEn: 'E', frequency: 329.63, index: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    // Determine active string
    _GuitarString? activeString;
    double deviation = 0;
    bool inTune = false;

    if (!result.isSilent && result.frequency > 60) {
      activeString = strings.reduce((a, b) {
        return (result.frequency - a.frequency).abs() <
                (result.frequency - b.frequency).abs()
            ? a
            : b;
      });

      if ((result.frequency - activeString.frequency).abs() > 20) {
        activeString = null;
      } else {
        deviation = result.frequency - activeString.frequency;
        inTune = deviation.abs() < 0.8;

        // Mark string as tuned when in tune
        if (inTune) {
          _tunedStrings.add(activeString.index);
        }
      }
    }

    // Calculate slider position (-1 to 1)
    double sliderPosition = 0;
    if (activeString != null) {
      // Map deviation to -1..1 range (max deviation ~10 Hz)
      sliderPosition = (deviation / 10.0).clamp(-1.0, 1.0);
    }

    final locale = ref.watch(localeProvider);
    final isRussian = locale.languageCode == 'ru';

    return Column(
      children: [
        const SizedBox(height: 16),

        // Tuning slider (oscilloscope style)
        _TuningSlider(
          position: sliderPosition,
          isActive: activeString != null,
          inTune: inTune,
        ),

        const SizedBox(height: 24),

        // Main content: Guitar image with string buttons on sides
        Expanded(
          child: Row(
            children: [
              // Left side strings: D, A, E (low)
              _StringButtonColumn(
                strings: [strings[2], strings[1], strings[0]], // Ре, Ля, Ми
                activeString: activeString,
                inTune: inTune,
                isRussian: isRussian,
                tunedStrings: _tunedStrings,
              ),

              // Center: Guitar headstock image
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/guitar.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Right side strings: G, B, E (high)
              _StringButtonColumn(
                strings: [strings[3], strings[4], strings[5]], // Соль, Си, Ми
                activeString: activeString,
                inTune: inTune,
                isRussian: isRussian,
                alignRight: true,
                tunedStrings: _tunedStrings,
              ),
            ],
          ),
        ),

        // Feedback text
        if (activeString != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              inTune
                  ? context.tr('perfect', ref)
                  : (deviation < 0
                        ? context.tr('too_low', ref)
                        : context.tr('too_high', ref)),
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: inTune ? Colors.greenAccent : Colors.amber,
              ),
            ),
          )
        else if (result.isSilent)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              context.tr('play_string', ref),
              style: GoogleFonts.outfit(fontSize: 22, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

class _GuitarString {
  final String name;
  final String nameEn;
  final double frequency;
  final int index;
  const _GuitarString({
    required this.name,
    required this.nameEn,
    required this.frequency,
    required this.index,
  });
}

/// Oscilloscope-style tuning slider
class _TuningSlider extends StatelessWidget {
  final double position; // -1 (flat) to 1 (sharp)
  final bool isActive;
  final bool inTune;

  const _TuningSlider({
    required this.position,
    required this.isActive,
    required this.inTune,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 60,
        child: CustomPaint(
          painter: _TuningSliderPainter(
            position: position,
            isActive: isActive,
            inTune: inTune,
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TuningSliderPainter extends CustomPainter {
  final double position;
  final bool isActive;
  final bool inTune;

  _TuningSliderPainter({
    required this.position,
    required this.isActive,
    required this.inTune,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final centerY = h / 2;

    // Draw background line
    final linePaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2;

    canvas.drawLine(Offset(20, centerY), Offset(w - 20, centerY), linePaint);

    // Draw tick marks
    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    for (int i = -5; i <= 5; i++) {
      final tickX = centerX + (i / 5.0) * (w / 2 - 30);
      final tickHeight = i == 0 ? 20.0 : 10.0;
      canvas.drawLine(
        Offset(tickX, centerY - tickHeight / 2),
        Offset(tickX, centerY + tickHeight / 2),
        tickPaint,
      );
    }

    // Draw flat and sharp symbols
    final textStyle = TextStyle(
      color: Colors.grey.shade500,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    final flatPainter = TextPainter(
      text: TextSpan(text: '♭', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    flatPainter.layout();
    flatPainter.paint(canvas, Offset(4, centerY - flatPainter.height / 2));

    final sharpPainter = TextPainter(
      text: TextSpan(text: '♯', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    sharpPainter.layout();
    sharpPainter.paint(
      canvas,
      Offset(w - sharpPainter.width - 4, centerY - sharpPainter.height / 2),
    );

    // Draw indicator circle
    if (isActive) {
      final indicatorX = centerX + position * (w / 2 - 40);
      final indicatorColor = inTune ? Colors.greenAccent : Colors.white;

      // Glow effect
      final glowPaint = Paint()
        ..color = indicatorColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(indicatorX, centerY), 16, glowPaint);

      // Main circle
      final indicatorPaint = Paint()
        ..color = indicatorColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(indicatorX, centerY), 12, indicatorPaint);

      // Border
      final borderPaint = Paint()
        ..color = indicatorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(indicatorX, centerY), 12, borderPaint);
    } else {
      // Draw inactive circle in center
      final inactivePaint = Paint()
        ..color = Colors.grey.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(centerX, centerY), 12, inactivePaint);
    }
  }

  @override
  bool shouldRepaint(_TuningSliderPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.isActive != isActive ||
        oldDelegate.inTune != inTune;
  }
}

/// Column of string selection buttons
class _StringButtonColumn extends StatelessWidget {
  final List<_GuitarString> strings;
  final _GuitarString? activeString;
  final bool inTune;
  final bool isRussian;
  final bool alignRight;
  final Set<int> tunedStrings;

  const _StringButtonColumn({
    required this.strings,
    required this.activeString,
    required this.inTune,
    required this.isRussian,
    required this.tunedStrings,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: strings.map((string) {
          final isActive = activeString?.index == string.index;
          final isCurrentlyInTune = isActive && inTune;
          final wasTuned = tunedStrings.contains(string.index);

          return _StringButton(
            label: isRussian ? string.name : string.nameEn,
            isActive: isActive,
            isInTune: isCurrentlyInTune,
            wasTuned: wasTuned,
          );
        }).toList(),
      ),
    );
  }
}

/// Individual string button widget
class _StringButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isInTune;
  final bool wasTuned;

  const _StringButton({
    required this.label,
    required this.isActive,
    required this.isInTune,
    required this.wasTuned,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.grey.shade600;
    Color textColor = Colors.grey.shade400;
    Color? backgroundColor;

    if (isActive) {
      // Currently active string
      borderColor = isInTune ? Colors.greenAccent : Colors.amber;
      textColor = Colors.white;
      backgroundColor = isInTune
          ? Colors.greenAccent.withOpacity(0.15)
          : Colors.amber.withOpacity(0.1);
    } else if (wasTuned) {
      // Previously tuned string - stays green
      borderColor = Colors.greenAccent;
      textColor = Colors.greenAccent;
      backgroundColor = Colors.greenAccent.withOpacity(0.1);
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: (isActive || wasTuned) ? 3 : 2,
        ),
        color: backgroundColor ?? Colors.transparent,
        boxShadow: (isActive || wasTuned)
            ? [
                BoxShadow(
                  color: borderColor.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
