import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:helpers/helpers.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:video_editor/widgets/crop/crop_grid_painter.dart';
import 'package:video_editor/utils/controller.dart';

enum ThumbnailType { trim, cover }

class ThumbnailSlider extends StatefulWidget {
  ThumbnailSlider({
    @required this.controller,
    this.height = 60,
    this.quality = 25,
    this.layoutWidth,
    @required this.type,
  }) : assert(controller != null);

  ///MAX QUALITY IS 100 - MIN QUALITY IS 0
  final int quality;

  ///THUMBNAIL HEIGHT
  final double height;
  final double layoutWidth;

  final VideoEditorController controller;

  final ThumbnailType type;

  @override
  _ThumbnailSliderState createState() => _ThumbnailSliderState();
}

class _ThumbnailSliderState extends State<ThumbnailSlider> {
  double _aspect = 1.0, _scale = 1.0;
  int _thumbnails = 8;

  Rect _rect;
  Size _size = Size.zero;
  Offset _translate = Offset.zero;
  Stream<List<Uint8List>> _stream;

  bool _isTrimmed;

  @override
  void initState() {
    super.initState();
    _aspect = widget.controller.video.value.aspectRatio;
    _isTrimmed = widget.controller.isTrimmmed;

    _size = _aspect <= 1.0
        ? Size(widget.height * _aspect, widget.height)
        : Size(widget.height, widget.height / _aspect);
    _thumbnails = (widget.layoutWidth ~/ _size.width) + 1;
    _stream = widget.type == ThumbnailType.trim
        ? _generateTrimThumbnails()
        : _generateCoverThumbnails();
    _rect = _calculateTrimRect();

    print(
        "THU*MNAIL SLIDER = layoutWidth=${widget.layoutWidth} sizeWidth=${_size.width}");
  }

  @override
  void didUpdateWidget(ThumbnailSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.controller.isPlaying)
      setState(() {
        _rect = _calculateTrimRect();
        final double _scaleX = _size.width / _rect.width;
        final double _scaleY = _size.height / _rect.height;

        _scale = _aspect <= 1.0
            ? _scaleX > _scaleY
                ? _scaleY
                : _scaleX
            : _scaleX < _scaleY
                ? _scaleY
                : _scaleX;
        _translate = Offset(
              (_size.width - _rect.width) / 2,
              (_size.height - _rect.height) / 2,
            ) -
            _rect.topLeft;
      });
  }

  Stream<List<Uint8List>> _generateTrimThumbnails() async* {
    final String path = widget.controller.file.path;
    final int duration = widget.controller.videoDuration.inMilliseconds;
    final double eachPart = duration / _thumbnails;

    List<Uint8List> _byteList = [];

    for (int i = 1; i <= _thumbnails; i++) {
      Uint8List _bytes = await VideoThumbnail.thumbnailData(
        imageFormat: ImageFormat.JPEG,
        video: path,
        timeMs: (eachPart * i).toInt(),
        quality: widget.quality,
      );
      _byteList.add(_bytes);

      yield _byteList;
    }
  }

  Stream<List<Uint8List>> _generateCoverThumbnails() async* {
    final String path = widget.controller.file.path;

    final int duration = _isTrimmed
        ? (widget.controller.endTrim - widget.controller.startTrim)
            .inMilliseconds
        : widget.controller.videoDuration.inMilliseconds;

    final double eachPart = duration / _thumbnails;

    List<Uint8List> _byteList = [];

    for (int i = 1; i <= _thumbnails; i++) {
      Uint8List _bytes = await VideoThumbnail.thumbnailData(
        imageFormat: ImageFormat.JPEG,
        video: path,
        timeMs: (_isTrimmed
                ? (eachPart * i) + widget.controller.startTrim.inMilliseconds
                : (eachPart * i))
            .toInt(),
        quality: widget.quality,
      );
      _byteList.add(_bytes);

      yield _byteList;
    }
  }

  Rect _calculateTrimRect() {
    final Offset min = widget.controller.minCrop;
    final Offset max = widget.controller.maxCrop;
    return Rect.fromPoints(
      Offset(
        min.dx * _size.width,
        min.dy * _size.height,
      ),
      Offset(
        max.dx * _size.width,
        max.dy * _size.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _stream,
      builder: (_, AsyncSnapshot<List<Uint8List>> snapshot) {
        final data = snapshot.data;
        return snapshot.hasData
            ? ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: data.length,
                itemBuilder: (_, int index) {
                  return ClipRRect(
                    child: Transform.scale(
                      scale: _scale,
                      child: Transform.translate(
                        offset: _translate,
                        child: Container(
                          alignment: Alignment.center,
                          height: _size.height,
                          width: _size.width,
                          child: _croppedThumbnail(_size.width, _size.height,
                              data[index], data[index > 0 ? index - 1 : 0]),
                          //_notCroppedThumbnail(data[index]),
                        ),
                      ),
                    ),
                  );
                },
              )
            : SizedBox();
      },
    );
  }

  Widget _notCroppedThumbnail(Uint8List data) {
    return new Stack(children: [
      Image(
        image: MemoryImage(data),
        width: _size.width,
        height: _size.height,
        alignment: Alignment.topLeft,
      ),
      CustomPaint(
        size: _size,
        painter: CropGridPainter(
          _rect,
          showGrid: false,
          style: widget.controller.cropStyle,
        ),
      )
    ]);
  }

  /// Use overflow widget to hide cropped crop painted area in thumbnails
  Widget _croppedThumbnail(
      double sizeWidth, double sizeHeight, Uint8List data, Uint8List prevData) {
    final bool _modePortrait = sizeHeight >= sizeWidth;
    return new Container(
      width: sizeWidth,
      height: _modePortrait ? sizeWidth : sizeHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Container(
              width: sizeWidth,
              height: sizeWidth / widget.controller.video.value.aspectRatio,
              child: ClipRRect(
                child: Stack(children: [
                  Image(
                    image: MemoryImage(data != null
                        ? data
                        : prevData), // If last thumbmnail is null display the previous one (avoid bytes != null error)
                    width: _size.width,
                    height: _size.height,
                    alignment: Alignment.topLeft,
                  ),
                  _modePortrait
                      ? CustomPaint(
                          size: _size,
                          painter: CropGridPainter(
                            _rect,
                            showGrid: false,
                            style: widget.controller.cropStyle,
                          ),
                        )
                      : Container()
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
