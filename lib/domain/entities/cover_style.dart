import 'package:flutter/material.dart';

class CoverSliderStyle {
  ///Style for [CoverSlider]. It's use on VideoEditorController
  CoverSliderStyle({
    Color? background,
    this.lineWidth = 2,
    this.lineColor = Colors.white,
  }) : this.background = background ?? Colors.black.withOpacity(0.6);

  ///It is the deactive color. Default `Colors.black.withOpacity(0.6)
  final Color background;

  final Color lineColor;
  final double lineWidth;
}
