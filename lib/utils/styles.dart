import 'package:flutter/material.dart';

class CropGridStyle {
  ///Style for [CropGridViewer]. It's use on VideoEditorController
  CropGridStyle({
    Color croppingBackground,
    this.background = Colors.black,
    this.gridLineColor = Colors.white,
    this.gridLineWidth = 1,
    this.gridSize = 3,
    this.boundariesColor = Colors.white,
    this.boundariesLenght = 20,
    this.boundariesWidth = 5,
  }) : this.croppingBackground =
            croppingBackground ?? Colors.black.withOpacity(0.48);

  ///It is the deactive color background when is cropping. Default `Colors.black.withOpacity(0.48)`
  final Color croppingBackground;

  ///It is the background color when is not cropping.
  final Color background;

  final double gridLineWidth;

  final Color gridLineColor;

  ///The amount columns and rows
  final int gridSize;

  final Color boundariesColor;
  final double boundariesLenght;
  final double boundariesWidth;
}

class TrimSliderStyle {
  ///Style for [TrimSlider]. It's use on VideoEditorController
  TrimSliderStyle({
    Color background,
    this.positionLineColor = Colors.white,
    this.positionlineWidth = 2,
    this.sideTrimmerColor = Colors.black,
    this.sideTrimmerWidth = 18,
    this.innerSideTrimmerColor = Colors.white,
    this.innerSideTrimmerWidth = 5,
  }) : this.background = background ?? Colors.black.withOpacity(0.6);

  ///It is the color line that indicate the video position
  final Color positionLineColor;
  final double positionlineWidth;

  final Color sideTrimmerColor;
  final double sideTrimmerWidth;

  final Color innerSideTrimmerColor;
  final double innerSideTrimmerWidth;

  ///It is the deactive color. Default `Colors.black.withOpacity(0.6)
  final Color background;
}

class CoverSliderStyle {
  ///Style for [TrimSlider]. It's use on VideoEditorController
  CoverSliderStyle({
    Color background,
    this.lineWidth = 4,
    this.lineColor = Colors.white,
  }) : this.background = background ?? Colors.white.withOpacity(0.6);

  ///It is the deactive color. Default `Colors.white.withOpacity(0.6)
  final Color background;

  final Color lineColor;
  final double lineWidth;
}
