import 'package:flutter/material.dart';
import 'package:helpers/helpers.dart';
import 'package:video_editor/utils/controller.dart';
import 'package:video_editor/widgets/trim/trim_slider_painter.dart';
import 'package:video_editor/widgets/thumbnail/thumbnail_slider.dart';
import 'package:video_player/video_player.dart';

enum _TrimBoundaries { left, right, inside, progress }

class TrimSlider extends StatefulWidget {
  ///Slider that trim video length.
  TrimSlider({
    Key key,
    @required this.controller,
    this.height = 60,
    this.quality = 25,
    this.margin,
  }) : super(key: key);

  ///**Quality of thumbnails:** 0 is the worst quality and 100 is the highest quality.
  final int quality;

  ///It is the height of the thumbnails
  final double height;

  ///Essential argument for the functioning of the Widget
  final VideoEditorController controller;

  final double margin;

  @override
  _TrimSliderState createState() => _TrimSliderState();
}

class _TrimSliderState extends State<TrimSlider>
    with AutomaticKeepAliveClientMixin<TrimSlider> {
  final _boundary = ValueNotifier<_TrimBoundaries>(null);
  final _scrollController = ScrollController();
  Rect _rect;

  Size _trimLayout = Size.zero;
  Size _fullLayout = Size.zero;
  VideoPlayerController _controller;

  double _thumbnailPosition = 0.0;
  double _ratio;
  int _timeGap;
  double _cropHeight;
  double _trimWidth;

  @override
  void initState() {
    _controller = widget.controller.video;

    _ratio = getRatioDuration();
    final duration =
        widget.controller.maxDuration < widget.controller.videoDuration
            ? widget.controller.maxDuration
            : widget.controller.videoDuration;
    _timeGap = (duration.inSeconds / 6).ceil();

    _cropHeight = widget.controller.video.value.aspectRatio <= 1.0
        ? widget.height * widget.controller.video.value.aspectRatio
        : widget.height / widget.controller.video.value.aspectRatio;

    _trimWidth = widget.controller.trimStyle.sideTrimmerWidth;

    super.initState();
  }

  @override
  bool get wantKeepAlive => true;

  //--------//
  //GESTURES//
  //--------//
  void _onHorizontalDragStart(DragStartDetails details) {
    final double margin = 25.0 + widget.margin;
    final double pos = details.localPosition.dx;
    final double max = _rect.right;
    final double min = _rect.left;
    final double progressTrim = _getTrimPosition();
    final List<double> minMargin = [min - margin, min + margin];
    final List<double> maxMargin = [max - margin, max + margin];

    //IS TOUCHING THE GRID
    if (pos >= minMargin[0] && pos <= maxMargin[1]) {
      //TOUCH BOUNDARIES
      if (pos >= minMargin[0] && pos <= minMargin[1])
        _boundary.value = _TrimBoundaries.left;
      else if (pos >= maxMargin[0] && pos <= maxMargin[1])
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
          if (pos.dx > widget.margin && pos.dx < _rect.right - _trimWidth * 2)
            _changeTrimRect(left: pos.dx, width: _rect.width - delta.dx);
          break;
        case _TrimBoundaries.right:
          final pos = _rect.topRight + delta;
          if (pos.dx < _trimLayout.width + widget.margin &&
              pos.dx > _rect.left + _trimWidth * 2)
            _changeTrimRect(width: _rect.width + delta.dx);
          break;
        case _TrimBoundaries.inside:
          final pos = _rect.topLeft + delta;
          // Move thumbs slider when the trimmer is on the edges
          if (_rect.topLeft.dx + delta.dx < widget.margin ||
              _rect.topRight.dx + delta.dx > _trimLayout.width) {
            _scrollController.position.moveTo(
              _scrollController.offset + delta.dx,
            );
          }
          if (pos.dx > widget.margin && pos.dx < _rect.right)
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
    return _fullLayout.width * widget.controller.trimPosition -
        _thumbnailPosition +
        widget.margin;
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
      final Size fullLayout =
          Size(trimLayout.width * (_ratio > 1 ? _ratio : 1), height);
      _fullLayout = fullLayout;
      if (_trimLayout != trimLayout) {
        _trimLayout = trimLayout;
        _createTrimRect();
      }

      return Container(
          width: _fullLayout.width,
          child: Stack(children: [
            NotificationListener<ScrollNotification>(
              child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    margin: Margin.horizontal(widget.margin),
                    child: Column(children: [
                      SizedBox(
                          height: widget.height,
                          width: _fullLayout.width,
                          child: ThumbnailSlider(
                              controller: widget.controller,
                              height: widget.height,
                              quality: widget.quality,
                              type: ThumbnailType.trim)),
                      Container(
                          width: _fullLayout.width,
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (int i = 0;
                                    i <=
                                        (widget.controller.videoDuration
                                                    .inSeconds /
                                                _timeGap)
                                            .ceil();
                                    i++)
                                  Text(
                                    (i * _timeGap <=
                                                widget.controller.videoDuration
                                                    .inSeconds
                                            ? i * _timeGap
                                            : '')
                                        .toString(),
                                  ),
                              ]))
                    ]),
                  )),
              onNotification: (notification) {
                _boundary.value = _TrimBoundaries.inside;
                _updateControllerIsTrimming(true);
                if (notification is ScrollEndNotification) {
                  _thumbnailPosition = notification.metrics.pixels;
                  _controllerSeekTo(_rect.left);
                  _updateControllerIsTrimming(false);
                  _updateControllerTrim();
                }
                return true;
              },
            ),
            GestureDetector(
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return CustomPaint(
                      size: Size.fromHeight(widget.height),
                      painter: TrimSliderPainter(
                        _rect,
                        _getTrimPosition(),
                        // Compute cropped height to not display cropped painted area in thumbnails slider
                        cropHeight: _cropHeight,
                        style: widget.controller.trimStyle,
                      ),
                    );
                  },
                )),
          ]));
    });
  }
}
