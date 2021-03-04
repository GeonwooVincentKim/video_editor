import 'package:flutter/material.dart';
import 'package:video_editor/utils/styles.dart';

class TrimSliderPainter extends CustomPainter {
  TrimSliderPainter(this.rect, this.position, {this.style});

  final Rect rect;
  final double position;
  final TrimSliderStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = style.background;
    final progress = Paint()
      ..color = style.positionLineColor
      ..strokeWidth = style.positionlineWidth;
    final side = Paint()
      ..color = style.sideTrimmerColor
      ..strokeWidth = style.sideTrimmerWidth;
    final sideInner = Paint()
      ..color = style.innerSideTrimmerColor
      ..strokeWidth = style.innerSideTrimmerWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(
      Rect.fromPoints(
        Offset(position - progress.strokeWidth / 2, 0.0),
        Offset(position + progress.strokeWidth / 2, size.height),
      ),
      progress,
    );

    //BACKGROUND LEFT
    canvas.drawRect(
      Rect.fromPoints(
        Offset.zero,
        rect.bottomLeft,
      ),
      background,
    );

    //BACKGROUND RIGHT
    canvas.drawRect(
      Rect.fromPoints(
        rect.topRight,
        Offset(size.width, size.height),
      ),
      background,
    );

    //LEFT LINE
    canvas.drawLine(
      rect.bottomLeft,
      rect.topLeft,
      side,
    );

    //RIGHT LINE
    canvas.drawLine(
      rect.bottomRight,
      rect.topRight,
      side,
    );

    //LEFT INNER LINE
    canvas.drawLine(Offset(rect.left, rect.height * 0.25),
        Offset(rect.left, rect.height * 0.75), sideInner);

    //RIGHT INNER LINE
    canvas.drawLine(Offset(rect.right, rect.height * 0.25),
        Offset(rect.right, rect.height * 0.75), sideInner);
  }

  @override
  bool shouldRepaint(TrimSliderPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(TrimSliderPainter oldDelegate) => false;
}
