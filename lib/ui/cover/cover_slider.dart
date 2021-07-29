import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_editor/domain/bloc/controller.dart';
import 'package:video_editor/ui/trim/thumbnail_slider.dart';
import 'package:video_editor/ui/cover/cover_slider_painter.dart';

class CoverSlider extends StatefulWidget {
  ///Slider that trim video length.
  CoverSlider({
    Key? key,
    required this.controller,
    this.height = 60,
    this.quality = 10,
  }) : super(key: key);

  ///**Quality of thumbnails:** 0 is the worst quality and 100 is the highest quality.
  final int quality;

  ///It is the height of the thumbnails
  final double height;

  ///Essential argument for the functioning of the Widget
  final VideoEditorController controller;

  @override
  _CoverSliderState createState() => _CoverSliderState();
}

class _CoverSliderState extends State<CoverSlider>
    with AutomaticKeepAliveClientMixin<CoverSlider> {
  Rect _rect = Rect.zero;
  double _rectWidth = 0.0;
  Size _layout = Size.zero;
  late VideoPlayerController _controller;

  @override
  void initState() {
    _rectWidth = widget.height;
    _controller = widget.controller.video;
    widget.controller.defaultCover = false;
    super.initState();
  }

  @override
  bool get wantKeepAlive => true;

  //--------//
  //GESTURES//
  //--------//
  void _onHorizontalDragStart(DragStartDetails details) {
    _controller.pause();

    final double margin = 25.0;
    final double pos = details.localPosition.dx;
    final double max = _rect.right;
    final double min = _rect.left;
    final List<double> minMargin = [min - margin, min + margin];
    final List<double> maxMargin = [max - margin, max + margin];

    //IS TOUCHING THE GRID
    if (pos >= minMargin[0] && pos <= maxMargin[1]) {
      _updateControllerIsCovering(true);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final Offset delta = details.delta;
    final pos = _rect.topLeft + delta;
    _changeCoverRect(left: pos.dx);
  }

  void _onHorizontalDragEnd(_) {
    _updateControllerIsCovering(false);
    _updateControllerCover();
  }

  //----//
  //RECT//
  //----//
  void _changeCoverRect({double? left}) {
    left = left ?? _rect.left;

    if (left >= 0 && left + _rectWidth <= _layout.width) {
      _rect = Rect.fromLTWH(left, _rect.top, _rectWidth, _rect.height);
      _updateControllerCover();
    }
  }

  void _createCoverRect() {
    void _normalRect() {
      _rect = Rect.fromPoints(
        Offset(widget.controller.coverPosition * _layout.width, 0.0),
        Offset((widget.controller.coverPosition * _layout.width) + _rectWidth,
            widget.height),
      );
    }

    if (_rect == Rect.zero && widget.controller.coverPosition == 0.0) {
      _rect = Rect.fromLTWH(
        0.0,
        0.0,
        _rectWidth,
        widget.height,
      );
    } else
      _normalRect();
  }

  //----//
  //MISC//
  //----//
  void _controllerSeekToCoverPos() {
    print('cover time = ${widget.controller.coverTime()}');
    _controller.seekTo(widget.controller
        .coverTime()); // TODO FIX: video_player iOS bug to seek video while paused (https://github.com/flutter/flutter/issues/80054)
  }

  void _updateControllerCover() {
    final double width = _layout.width;
    widget.controller.updateCover(_rect.left / width);
    _controllerSeekToCoverPos();
  }

  void _updateControllerIsCovering(bool value) {
    widget.controller.isCovering = value;
  }

  double _getCoverPosition() {
    return _layout.width * widget.controller.coverPosition;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(builder: (_, contrainst) {
      final Size layout = Size(contrainst.maxWidth, contrainst.maxHeight);
      if (_layout != layout) {
        _layout = layout;
        _createCoverRect();
      }

      return GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
          ThumbnailSlider(
              controller: widget.controller,
              height: widget.height,
              quality: widget.quality),
          AnimatedBuilder(
            animation: Listenable.merge([widget.controller, _controller]),
            builder: (_, __) {
              return CustomPaint(
                size: Size.infinite,
                painter: CoverSliderPainter(
                  _rect,
                  _getCoverPosition(),
                  style: widget.controller.coverStyle,
                ),
              );
            },
          ),
        ]),
      );
    });
  }
}
