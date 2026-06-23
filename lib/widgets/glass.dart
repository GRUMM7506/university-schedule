import 'dart:ui';

import 'package:flutter/material.dart';

class AppGlassBackground extends StatelessWidget {
  const AppGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF07111F),
                  Color(0xFF0F172A),
                  Color(0xFF172554),
                  Color(0xFF0F766E),
                ]
              : const [
                  Color(0xFFE0F2FE),
                  Color(0xFFF8FAFC),
                  Color(0xFFECFDF5),
                  Color(0xFFDBEAFE),
                ],
        ),
      ),
      child: CustomPaint(
        painter: _GlassBackgroundPainter(dark: dark),
        child: child,
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 22,
    this.opacity,
    this.borderOpacity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? opacity;
  final double? borderOpacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveOpacity = opacity ?? (dark ? .18 : .62);
    final effectiveBorderOpacity = borderOpacity ?? (dark ? .18 : .72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: effectiveOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: effectiveBorderOpacity),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .24 : .08),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _GlassBackgroundPainter extends CustomPainter {
  const _GlassBackgroundPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF0F172A))
          .withValues(alpha: dark ? .055 : .045)
      ..strokeWidth = 1;

    const spacing = 42.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * .28, size.height), linePaint);
    }
    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - size.width * .08), linePaint);
    }

    final panelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: dark ? .08 : .34);

    final rects = [
      Rect.fromLTWH(size.width * .64, size.height * .08, 260, 120),
      Rect.fromLTWH(size.width * .08, size.height * .72, 320, 150),
      Rect.fromLTWH(size.width * .76, size.height * .72, 220, 110),
    ];
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(24)),
        panelPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassBackgroundPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}
