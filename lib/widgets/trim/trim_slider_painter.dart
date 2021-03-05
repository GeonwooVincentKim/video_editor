import 'package:flutter/material.dart';
import 'package:video_editor/utils/styles.dart';

class TrimSliderPainter extends CustomPainter {
  TrimSliderPainter(this.rect, this.position, {this.style, this.cropHeight});

  final Rect rect;
  final double position;
  final TrimSliderStyle style;
  final double cropHeight;

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

    if (cropHeight != null) {
      final topCropPosition = (size.height - cropHeight) / 2;
      final bottomCropPosition = (size.height - cropHeight) / 2 + cropHeight;
      // POSITION BAR
      canvas.drawRect(
        Rect.fromPoints(
          Offset(position - progress.strokeWidth / 2, topCropPosition),
          Offset(position + progress.strokeWidth / 2, bottomCropPosition),
        ),
        progress,
      );
      // BACKGROUND LEFT
      canvas.drawRect(
          Rect.fromLTWH(0, topCropPosition, rect.left, cropHeight), background);

      // BACKGROUND RIGHT
      canvas.drawRect(
          Rect.fromLTWH(rect.right, topCropPosition, size.width, cropHeight),
          background);

      //LEFT LINE
      canvas.drawLine(
        Offset(rect.left + side.strokeWidth / 2, topCropPosition),
        Offset(rect.left + side.strokeWidth / 2, bottomCropPosition),
        side,
      );
      //RIGHT LINE
      canvas.drawLine(
        Offset(rect.right - side.strokeWidth / 2, topCropPosition),
        Offset(rect.right - side.strokeWidth / 2, bottomCropPosition),
        side,
      );
      //LEFT INNER LINE
      canvas.drawLine(
          Offset(rect.left + side.strokeWidth / 2,
              (size.height + topCropPosition) * 0.33),
          Offset(rect.left + side.strokeWidth / 2,
              (size.height - topCropPosition) * 0.66),
          sideInner);
      //RIGHT INNER LINE
      canvas.drawLine(
          Offset(rect.right - side.strokeWidth / 2,
              (size.height + topCropPosition) * 0.33),
          Offset(rect.right - side.strokeWidth / 2,
              (size.height - topCropPosition) * 0.66),
          sideInner);
    } else {
      // POSITION BAR
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
  }

  @override
  bool shouldRepaint(TrimSliderPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(TrimSliderPainter oldDelegate) => false;
}
