import 'package:flutter/material.dart';
import 'package:helpers/helpers.dart';
import 'package:video_editor/utils/controller.dart';
import 'package:video_editor/utils/styles.dart';
import 'package:video_editor/widgets/trim/trim_slider_painter.dart';
import 'package:video_editor/widgets/thumbnail/thumbnail_slider.dart';
import 'package:video_player/video_player.dart';

enum _TrimBoundaries { left, right, inside, progress }

enum _TrimStyle { selection, entire }

class TrimSlider extends StatefulWidget {
  ///Slider that trim video length.
  TrimSlider({
    Key key,
    @required this.controller,
    this.height = 60,
    this.quality = 25,
    this.trimBar,
    this.margin,
  }) : super(key: key);

  ///**Quality of thumbnails:** 0 is the worst quality and 100 is the highest quality.
  final int quality;

  ///It is the height of the thumbnails
  final double height;

  ///Essential argument for the functioning of the Widget
  final VideoEditorController controller;

  final AssetImage trimBar;
  final double margin;

  @override
  _TrimSliderState createState() => _TrimSliderState();
}

class _TrimSliderState extends State<TrimSlider> {
  final _boundary = ValueNotifier<_TrimBoundaries>(null);

  Rect _rect;

  Size _trimLayout = Size.zero;
  Size _fullLayout = Size.zero;
  VideoPlayerController _controller;

  double _thumbnailPosition = 0.0;
  _TrimStyle _style;
  final double trimBarWidth = 15;

  @override
  void initState() {
    _controller = widget.controller.video;

    _style = _TrimStyle.entire;
    if (widget.controller.maxDuration != null &&
        widget.controller.maxDuration < widget.controller.videoDuration)
      _style = _TrimStyle.selection;

    super.initState();
  }

  //--------//
  //GESTURES//
  //--------//
  void _onHorizontalDragStart(DragStartDetails details) {
    print("ON HORIZONTAL DRAG START");

    final double margin = 25.0;
    final double sideWidth = 4.0;
    final double pos = details.localPosition.dx;
    final double max = _rect.right;
    final double min = _rect.left;
    final double progressTrim = _getTrimPosition();
    final List<double> minMargin = [min - margin, min + margin];
    final List<double> maxMargin = [max - margin, max + margin];

    //IS TOUCHING THE GRID
    if (pos >= minMargin[0] && pos <= maxMargin[1]) {
      //TOUCH BOUNDARIES
      if (pos + sideWidth >= minMargin[0] && pos - sideWidth <= minMargin[1])
        _boundary.value = _TrimBoundaries.left;
      else if (pos + sideWidth >= maxMargin[0] &&
          pos - sideWidth <= maxMargin[1])
        _boundary.value = _TrimBoundaries.right;
      else if (pos >= progressTrim - margin && pos <= progressTrim + margin)
        _boundary.value = _TrimBoundaries.progress;
      else if (pos >= minMargin[1] && pos <= maxMargin[0])
        _boundary.value = _TrimBoundaries.inside;
      else {
        _boundary.value = null;
        return null;
      }
      _updateControllerIsTrimming(true);
    } else {
      _boundary.value = null;
      return null;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_boundary.value != null) {
      final Offset delta = details.delta;
      switch (_boundary.value) {
        case _TrimBoundaries.left:
          final pos = _rect.topLeft + delta;
          _changeTrimRect(left: pos.dx, width: _rect.width - delta.dx);
          break;
        case _TrimBoundaries.right:
          _changeTrimRect(width: _rect.width + delta.dx);
          break;
        case _TrimBoundaries.inside:
          final pos = _rect.topLeft + delta;
          _changeTrimRect(left: pos.dx);
          break;
        case _TrimBoundaries.progress:
          final double pos = details.localPosition.dx;
          if (pos >= _rect.left && pos <= _rect.right) _controllerSeekTo(pos);
          break;
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_boundary.value != null) {
      final double _progressTrim = _getTrimPosition();

      if (_progressTrim >= _rect.right || _progressTrim < _rect.left)
        _controllerSeekTo(_progressTrim);

      _updateControllerIsTrimming(false);

      if (_boundary.value != _TrimBoundaries.progress) {
        if (_boundary.value != _TrimBoundaries.right)
          _controllerSeekTo(_rect.left);
        _updateControllerTrim();
      }
    }
  }

  void onLeftDragStart(DragStartDetails details) {
    _boundary.value = _TrimBoundaries.left;
    _updateControllerIsTrimming(true);
  }

  void onLeftDragUpdate(DragUpdateDetails details) {
    final Offset delta = details.delta;
    final pos = _rect.topLeft + delta;
    if ((_rect.topLeft + delta).dx > widget.margin &&
        (_rect.topLeft + delta).dx + trimBarWidth < _rect.right)
      _changeTrimRect(left: pos.dx, width: _rect.width - delta.dx);
  }

  void onLeftDragEnd(DragEndDetails details) {
    final double _progressTrim = _getTrimPosition();
    if (_progressTrim >= _rect.right || _progressTrim < _rect.left)
      _controllerSeekTo(_progressTrim);
    _updateControllerIsTrimming(false);
    _controllerSeekTo(_rect.left);
    _updateControllerTrim();
  }

  void onRightDragStart(DragStartDetails details) {
    _boundary.value = _TrimBoundaries.right;
    _updateControllerIsTrimming(true);
  }

  void onRightDragUpdate(DragUpdateDetails details) {
    final Offset delta = details.delta;
    if ((_rect.topRight + delta).dx < _trimLayout.width + widget.margin &&
        (_rect.topRight + delta).dx - trimBarWidth > _rect.left)
      _changeTrimRect(width: _rect.width + delta.dx);
  }

  void onRightDragEnd(DragEndDetails details) {
    final double _progressTrim = _getTrimPosition();
    if (_progressTrim >= _rect.right || _progressTrim < _rect.left)
      _controllerSeekTo(_progressTrim);
    _updateControllerIsTrimming(false);
    _updateControllerTrim();
  }

  //----//
  //RECT//
  //----//
  void _changeTrimRect({double left, double width}) {
    left = left ?? _rect.left;
    width = width ?? _rect.width;

    final Duration diff = _getDurationDiff(left, width);

    if (left >= 0 &&
        left + width - widget.margin <= _trimLayout.width &&
        diff <= widget.controller.maxDuration) {
      _rect = Rect.fromLTWH(left, _rect.top, width, _rect.height);
      _updateControllerTrim();
    }
  }

  void _createTrimRect() {
    _rect = Rect.fromPoints(
      Offset(
          widget.controller.minTrim * _fullLayout.width + widget.margin, 0.0),
      Offset(widget.controller.maxTrim * _fullLayout.width + widget.margin,
          widget.height),
    );
  }

  //----//
  //MISC//
  //----//
  void _controllerSeekTo(double position) async {
    await _controller.seekTo(
      _controller.value.duration * (position / _fullLayout.width),
    );
  }

  void _updateControllerTrim() {
    final double width = _fullLayout.width;
    widget.controller.updateTrim(
        (_rect.left + _thumbnailPosition - widget.margin) / width,
        (_rect.right + _thumbnailPosition - widget.margin) / width);
  }

  void _updateControllerIsTrimming(bool value) {
    if (_boundary.value != null && _boundary.value != _TrimBoundaries.progress)
      widget.controller.isTrimming = value;
  }

  double _getTrimPosition() {
    return _fullLayout.width * widget.controller.trimPosition;
  }

  double getRatioDuration() {
    return widget.controller.videoDuration.inMilliseconds /
        widget.controller.maxDuration.inMilliseconds;
  }

  Duration _getDurationDiff(double left, double width) {
    final double min = (left - widget.margin) / _fullLayout.width;
    final double max = (left + width - widget.margin) / _fullLayout.width;
    final Duration duration = _controller.value.duration;
    return (duration * max) - (duration * min);
  }

  @override
  Widget build(BuildContext context) {
    return SizeBuilder(builder: (width, height) {
      final Size trimLayout = Size(width - widget.margin * 2, height);
      final Size fullLayout = Size(
          _style == _TrimStyle.entire
              ? trimLayout.width
              : trimLayout.width * getRatioDuration(),
          height);
      _fullLayout = fullLayout;
      if (_trimLayout != trimLayout) {
        _trimLayout = trimLayout;
        _createTrimRect();
      }

      return Row(children: [
        Expanded(
            child: Container(
          width: _fullLayout.width,
          child: Stack(children: [
            NotificationListener<ScrollNotification>(
              child: ThumbnailSlider(
                  controller: widget.controller,
                  height: widget.height,
                  quality: widget.quality,
                  layoutWidth: _fullLayout.width,
                  type: ThumbnailType.trim),
              onNotification: (notification) {
                _boundary.value = _TrimBoundaries.inside;
                _updateControllerIsTrimming(true);
                if (notification is ScrollEndNotification) {
                  _thumbnailPosition = notification.metrics.pixels;
                  _controllerSeekTo(_rect.left + _thumbnailPosition);
                  _updateControllerIsTrimming(false);
                  _updateControllerTrim();
                }
                return true;
              },
            ),
            Container(
                child: Stack(
              children: [
                // LEFT BACKGROUND
                Positioned(
                    bottom: 0.0,
                    top: 0.0,
                    left: 0.0,
                    child: Opacity(
                        opacity: 0.6,
                        child: Container(
                          width: _rect.left - trimBarWidth / 2,
                          color: Colors.white,
                        ))),
                // LEFT TRIM BAR
                Positioned(
                    bottom: 0.0,
                    top: 0.0,
                    left: _rect.left - trimBarWidth / 2,
                    child: Container(
                        child: GestureDetector(
                            onHorizontalDragUpdate: onLeftDragUpdate,
                            onHorizontalDragStart: onLeftDragStart,
                            onHorizontalDragEnd: onLeftDragEnd,
                            child: Image(
                                image: widget.trimBar, width: trimBarWidth)))),
                // RIGHT BACKGROUND
                Positioned(
                    bottom: 0.0,
                    top: 0.0,
                    left: _rect.right - trimBarWidth / 2,
                    child: Opacity(
                        opacity: 0.6,
                        child: Container(
                          width:
                              fullLayout.width - _rect.right - trimBarWidth / 2,
                          color: Colors.white,
                        ))),
                // RIGHT TRIM BAR
                Positioned(
                    bottom: 0.0,
                    top: 0.0,
                    left: _rect.right - trimBarWidth / 2,
                    child: Container(
                        child: GestureDetector(
                            onHorizontalDragUpdate: onRightDragUpdate,
                            onHorizontalDragStart: onRightDragStart,
                            onHorizontalDragEnd: onRightDragEnd,
                            child: Image(
                                image: widget.trimBar, width: trimBarWidth)))),
              ],
            ))

            /*
            Container(
              padding: Margin.horizontal(widget.height / 4),
              child: GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  behavior: HitTestBehavior.translucent,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return CustomPaint(
                        //size: Size.fromWidth(layout.width - _rect.left),
                        painter: TrimSliderPainter(
                          _rect,
                          _getTrimPosition(),
                          // Compute cropped height to not display cropped painted area in thumbnails slider
                          cropHeight:
                              widget.controller.video.value.aspectRatio <= 1.0
                                  ? widget.height *
                                      widget.controller.video.value.aspectRatio
                                  : widget.height /
                                      widget.controller.video.value.aspectRatio,
                          style: widget.controller.trimStyle,
                        ),
                      );
                    },
                  )),
            )*/
          ]),
        ))
      ]);
    });
  }
}

class LeftTrimmer extends CustomPainter {
  LeftTrimmer(this.rect, this.position, {this.style, this.cropHeight});

  final Rect rect;
  final double position;
  final TrimSliderStyle style;
  final double cropHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = style.background;
    final side = Paint()
      ..color = style.sideTrimmerColor
      ..strokeWidth = style.sideTrimmerWidth;
    final sideInner = Paint()
      ..color = style.innerSideTrimmerColor
      ..strokeWidth = style.innerSideTrimmerWidth
      ..strokeCap = StrokeCap.round;
    final topCropPosition = (size.height - cropHeight) / 2;
    final bottomCropPosition = (size.height - cropHeight) / 2 + cropHeight;

    canvas.drawLine(
      Offset(rect.left + side.strokeWidth / 2, topCropPosition),
      Offset(rect.left + side.strokeWidth / 2, bottomCropPosition),
      side,
    );
    canvas.drawLine(
        Offset(rect.left + side.strokeWidth / 2,
            (size.height + topCropPosition) * 0.33),
        Offset(rect.left + side.strokeWidth / 2,
            (size.height - topCropPosition) * 0.66),
        sideInner);
    canvas.drawRect(
        Rect.fromLTWH(0, topCropPosition, rect.left, cropHeight), background);
  }

  @override
  bool shouldRepaint(LeftTrimmer oldDelegate) {
    return true;
  }
}
