import 'dart:io';
import 'package:flutter_ffmpeg/log_level.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_editor/utils/styles.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_ffmpeg/statistics.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

enum RotateDirection { left, right }

enum VideExportFramesExtractionMode { normal, opti }
const Duration MAX_DURATION_FRAMES_OPTI = Duration(seconds: 90);

///A preset is a collection of options that will provide a certain encoding speed to compression ratio.
///
///A slower preset will provide better compression (compression is quality per filesize).
///
///This means that, for example, if you target a certain file size or constant bit rate,
///you will achieve better quality with a slower preset.
///Similarly, for constant quality encoding,
///you will simply save bitrate by choosing a slower preset.

enum VideoExportPreset {
  none,
  ultrafast,
  superfast,
  veryfast,
  faster,
  fast,
  medium,
  slow,
  slower,
  veryslow
}

class VideoEditorController extends ChangeNotifier with WidgetsBindingObserver {
  ///Style for [TrimSlider]
  final TrimSliderStyle trimStyle;

  ///Style for [CropGridViewer]
  final CropGridStyle cropStyle;

  ///Style for [CoverSlider]
  final CoverSliderStyle coverStyle;

  ///Video from [File].
  final File file;

  ///Constructs a [VideoEditorController] that edits a video from a file.
  VideoEditorController.file(
    this.file, {
    Duration maxDuration,
    bool skipFramesExtraction = false,
    int fpsExtraction = 5,
    TrimSliderStyle trimStyle,
    CropGridStyle cropStyle,
    CoverSliderStyle coverStyle,
  })  : assert(file != null),
        _video = VideoPlayerController.file(file),
        this._maxDuration = maxDuration,
        this._skipFramesExtraction = skipFramesExtraction,
        this._fpsExtraction = fpsExtraction,
        this.cropStyle = cropStyle ?? CropGridStyle(),
        this.trimStyle = trimStyle ?? TrimSliderStyle(),
        this.coverStyle = coverStyle ?? CoverSliderStyle();

  FlutterFFmpeg _ffmpeg = FlutterFFmpeg();
  FlutterFFprobe _ffprobe = FlutterFFprobe();

  int _rotation = 0;
  bool isTrimming = false;
  bool _isTrimmed = false;
  bool isCropping = false;
  bool isCovering = false;
  bool _isExtractingFrames = false;
  double _minTrim = 0.0;
  double _maxTrim = 1.0;
  Offset _minCrop = Offset.zero;
  Offset _maxCrop = Offset(1.0, 1.0);

  Duration _trimEnd = Duration.zero;
  Duration _trimStart = Duration.zero;

  ///The max duration that can be trim video.
  Duration _maxDuration;

  bool _skipFramesExtraction;
  int _fpsExtraction;

  double _coverPos = 0.0;
  List<dynamic> _frames;
  List<dynamic> _selectionFrames;
  ValueNotifier<int> _coverIndex = ValueNotifier<int>(null);
  File _cover;

  String _editionName;
  Directory _editionTempDir;

  VideoPlayerController _video;
  VideExportFramesExtractionMode _framesExtractionMode;

  //----------------//
  //VIDEO CONTROLLER//
  //----------------//
  ///Attempts to open the given [File] and load metadata about the video.
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _video.initialize();
    _video.addListener(_videoListener);
    _video.setLooping(true);

    _editionName = path.basename(file.path).split('.')[0];
    final String tempPath =
        (await getTemporaryDirectory()).path + "/$_editionName/";
    _editionTempDir = new Directory(tempPath);

    _framesExtractionMode = VideExportFramesExtractionMode.normal;
    if (videoDuration <= MAX_DURATION_FRAMES_OPTI)
      _framesExtractionMode = VideExportFramesExtractionMode.opti;

    _maxDuration = _maxDuration == null ? videoDuration : _maxDuration;

    // Trim straight away when maxDuration is lower than video duration
    if (_maxDuration < videoDuration && !_skipFramesExtraction)
      updateTrim(
          0.0, _maxDuration.inMilliseconds / videoDuration.inMilliseconds);
    else
      _updateTrimRange();

    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    if (isPlaying) _video?.pause();
    _video.removeListener(_videoListener);
    _video.dispose();
    _video = null;
    final executions = await _ffmpeg.listExecutions();
    if (executions.length > 0) await _ffmpeg.cancel();
    _ffprobe = null;
    _ffmpeg = null;
    if (_editionTempDir.existsSync()) {
      await _editionTempDir.delete(recursive: true);
    }
    super.dispose();
  }

  void _videoListener() {
    if (videoPosition < _trimStart || videoPosition >= _trimEnd)
      _video.seekTo(_trimStart);
    notifyListeners();
  }

  ///Get the `VideoPlayerController`
  VideoPlayerController get video => _video;

  ///Get the `VideoPlayerController.value.initialized`
  bool get initialized => _video.value.initialized;

  ///Get the `VideoPlayerController.value.isPlaying`
  bool get isPlaying => _video.value.isPlaying;

  ///Get the `VideoPlayerController.value.position`
  Duration get videoPosition => _video.value.position;

  ///Get the `VideoPlayerController.value.duration`
  Duration get videoDuration => _video.value.duration;

  //----------//
  //VIDEO CROP//
  //----------//
  Future<String> _getCrop(String path) async {
    final info = await _ffprobe.getMediaInformation(path);
    final streams = info.getStreams();
    int _videoHeight = 0;
    int _videoWidth = 0;

    if (streams != null && streams.length > 0) {
      for (var stream in streams) {
        // Check side data for rotation (width and height are reverse opposite when the file come from camera)
        bool sideDataRotation = false;
        final sideDataList = stream.getAllProperties()['side_data_list'];
        if (sideDataList != null) {
          if (sideDataList[0]['rotation'] == 90 ||
              sideDataList[0]['rotation'] == -90) sideDataRotation = true;
        }

        int width = stream.getAllProperties()['width'];
        int height = stream.getAllProperties()['height'];
        // If video as been rotated : switch height and width
        if (sideDataRotation) {
          width = stream.getAllProperties()['height'];
          height = stream.getAllProperties()['width'];
        }
        if (width != null && width > _videoWidth) _videoWidth = width;
        if (height != null && height > _videoHeight) _videoHeight = height;
      }
    }

    final end = Offset(_videoWidth * _maxCrop.dx, _videoHeight * _maxCrop.dy);
    final start = Offset(_videoWidth * _minCrop.dx, _videoHeight * _minCrop.dy);
    return "crop=${end.dx - start.dx}:${end.dy - start.dy}:${start.dx}:${start.dy}";
  }

  ///Update minCrop and maxCrop.
  ///Arguments range are `Offset(0.0, 0.0)` to `Offset(1.0, 1.0)`.
  void updateCrop(Offset min, Offset max) {
    _minCrop = min;
    _maxCrop = max;
    notifyListeners();
  }

  ///Get the **TopLeftOffset** (Range is `Offset(0.0, 0.0)` to `Offset(1.0, 1.0)`).
  Offset get minCrop => _minCrop;

  ///Get the **BottomRightOffset** (Range is `Offset(0.0, 0.0)` to `Offset(1.0, 1.0)`).
  Offset get maxCrop => _maxCrop;

  //----------//
  //VIDEO TRIM//
  //----------//

  ///Update minTrim and maxTrim. Arguments range are `0.0` to `1.0`.
  void updateTrim(double min, double max) {
    _minTrim = min;
    _maxTrim = max;
    if (!_skipFramesExtraction) _updateTrimRange();
    notifyListeners();
  }

  void _updateTrimRange() async {
    _trimEnd = videoDuration * _maxTrim;
    _trimStart = videoDuration * _minTrim;

    if (!isTrimming && !_skipFramesExtraction) _initCover();

    if (_trimStart != Duration.zero || _trimEnd != videoDuration)
      _isTrimmed = true;
    else
      _isTrimmed = false;

    notifyListeners();
  }

  bool get isTrimmmed => _isTrimmed;

  Duration get startTrim => _trimStart;

  ///Get the **MinTrim** (Range is `0.0` to `1.0`).
  double get minTrim => _minTrim;

  Duration get endTrim => _trimEnd;

  ///Get the **MaxTrim** (Range is `0.0` to `1.0`).
  double get maxTrim => _maxTrim;

  Duration get maxDuration => _maxDuration;

  ///Get the **VideoPosition** (Range is `0.0` to `1.0`).
  double get trimPosition =>
      videoPosition.inMilliseconds / videoDuration.inMilliseconds;

  //----------//
  //VIDEO COVER//
  //----------//

  void _initCover() async {
    if (_skipFramesExtraction) return null;

    final executions = await _ffmpeg.listExecutions();
    if (executions.length > 0) _ffmpeg.cancel();

    if (_framesExtractionMode == VideExportFramesExtractionMode.normal) {
      _getFrames(false);
      notifyListeners();
    } else if (_framesExtractionMode == VideExportFramesExtractionMode.opti) {
      if (_frames == null) {
        _getFrames(true);
      } else {
        _selectionFrames = _frames.sublist(
            _trimStart.inSeconds * _fpsExtraction,
            _trimEnd.inSeconds * _fpsExtraction);
        _cover = new File(_selectionFrames.first.path);
      }
      notifyListeners();
    }
  }

  void _getFrames(bool fullFrames) async {
    _isExtractingFrames = true;
    _coverPos = 0.0;
    final listFrames = await extractFrames(fullFrames: fullFrames);
    // Sort files to be sure to store them in alphabetical order
    if (listFrames != null) {
      listFrames.sort((a, b) {
        return a.path.compareTo(b.path);
      });
      _frames = listFrames;

      if (_framesExtractionMode == VideExportFramesExtractionMode.opti) {
        _selectionFrames = listFrames.sublist(
            _trimStart.inSeconds * _fpsExtraction,
            _trimEnd.inSeconds * _fpsExtraction);
        _cover = new File(_selectionFrames.first.path);
      } else
        _cover = new File(_frames.first.path);
      _coverIndex.value = 0;
      _isExtractingFrames = false;
    }
  }

  void updateCover(double coverPos) async {
    _coverPos = coverPos;
    _coverIndex.value = (frames.length * coverPos).toInt();
    _cover = new File(frames[_coverIndex.value].path);
    notifyListeners();
  }

  /// Return the position of the cover in Duration format on all the video (no trim)
  Duration _coverTime() {
    return new Duration(
        milliseconds: (_isTrimmed
                ? ((_trimEnd - _trimStart).inMilliseconds * _coverPos) +
                    _trimStart.inMilliseconds
                : videoDuration.inMilliseconds * _coverPos)
            .toInt());
  }

  bool get isExtractingFrames => _isExtractingFrames;
  double get coverPosition => _coverPos;
  File get cover => _cover;
  ValueNotifier<int> get coverIndex => _coverIndex;
  List<dynamic> get frames {
    return _framesExtractionMode == VideExportFramesExtractionMode.normal
        ? _frames
        : _selectionFrames;
  }

  ///Don't touch this >:)

  //------------//
  //VIDEO ROTATE//
  //------------//
  void rotate90Degrees([RotateDirection direction = RotateDirection.right]) {
    switch (direction) {
      case RotateDirection.left:
        _rotation += 90;
        if (_rotation >= 360) _rotation = _rotation - 360;
        break;
      case RotateDirection.right:
        _rotation -= 90;
        if (_rotation <= 0) _rotation = 360 + _rotation;
        break;
    }
    notifyListeners();
  }

  String _getRotation() {
    List<String> transpose = [];
    for (int i = 0; i < _rotation / 90; i++) transpose.add("transpose=2");
    return transpose.length > 0 ? "${transpose.join(',')}" : "";
  }

  int get rotation => _rotation;

  //------------//
  //VIDEO EXPORT//
  //------------//
  ///Export the video at `TemporaryDirectory` and return a `File`.
  ///
  ///
  ///If the [name] is `null`, then it uses the filename.
  ///
  ///
  ///The [scaleVideo] is `scale=width*scale:height*scale` and reduce o increase video size.
  ///
  ///The [progressCallback] is called while the video is exporting. This argument is usually used to update the export progress percentage.
  ///
  ///The [preset] is the `compress quality` **(Only available on full-lts package)**.
  ///A slower preset will provide better compression (compression is quality per filesize).
  ///**More info about presets**:  https://ffmpeg.org/ffmpeg-formats.htmlhttps://trac.ffmpeg.org/wiki/Encode/H.264
  Future<File> exportVideo({
    String name,
    String format = "mp4",
    double scale = 1.0,
    String customInstruction,
    void Function(Statistics) progressCallback,
    VideoExportPreset preset = VideoExportPreset.none,
  }) async {
    final FlutterFFmpegConfig _config = FlutterFFmpegConfig();
    _config.setLogLevel(LogLevel.AV_LOG_WARNING);
    final String tempPath = (await getTemporaryDirectory()).path;
    final String videoPath = file.path;
    final String outputPath = tempPath.toString() +
        "/" +
        _editionName.toString() +
        "_" +
        DateTime.now().millisecondsSinceEpoch.toString() +
        ".$format";

    //-----------------//
    //CALCULATE FILTERS//
    //-----------------//
    final String gif = format != "gif" ? "" : "fps=10 -loop 0";
    final String trim = _minTrim == 0.0 && _maxTrim == 1.0
        ? ""
        : "-ss $_trimStart -to $_trimEnd";
    final String crop = _minCrop == Offset.zero && _maxCrop == Offset(1.0, 1.0)
        ? ""
        : await _getCrop(videoPath);
    final String rotation =
        _rotation >= 360 || _rotation <= 0 ? "" : _getRotation();
    final String scaleInstruction =
        scale == 1.0 ? "" : "scale=iw*$scale:ih*$scale";

    //----------------//
    //VALIDATE FILTERS//
    //----------------//
    final List<String> filters = [crop, scaleInstruction, rotation, gif];
    filters.removeWhere((item) => item.isEmpty);
    final String filter =
        filters.isNotEmpty ? "-filter:v " + filters.join(",") : "";
    final String execute =
        " -i $videoPath ${customInstruction ?? ""} $filter ${_getPreset(preset)} $trim -y $outputPath";

    if (progressCallback != null)
      _config.enableStatisticsCallback(progressCallback);
    final int code = await _ffmpeg.execute(execute);
    _config.enableStatisticsCallback(null);

    //------//
    //RESULT//
    //------//
    if (code == 0) {
      print("SUCCESS EXPORT AT $outputPath");
      return File(outputPath);
    } else if (code == 255) {
      print("USER CANCEL EXPORT");
      return null;
    } else {
      print("ERROR ON EXPORT VIDEO (CODE $code)");
      return null;
    }
  }

  String _getPreset(VideoExportPreset preset) {
    String newPreset = "medium";

    switch (preset) {
      case VideoExportPreset.ultrafast:
        newPreset = "ultrafast";
        break;
      case VideoExportPreset.superfast:
        newPreset = "superfast";
        break;
      case VideoExportPreset.veryfast:
        newPreset = "veryfast";
        break;
      case VideoExportPreset.faster:
        newPreset = "faster";
        break;
      case VideoExportPreset.fast:
        newPreset = "fast";
        break;
      case VideoExportPreset.medium:
        newPreset = "medium";
        break;
      case VideoExportPreset.slow:
        newPreset = "slow";
        break;
      case VideoExportPreset.slower:
        newPreset = "slower";
        break;
      case VideoExportPreset.veryslow:
        newPreset = "veryslow";
        break;
      case VideoExportPreset.none:
        break;
    }

    return preset == VideoExportPreset.none ? "" : "-preset $newPreset";
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String stringMillis = duration.inMilliseconds.remainder(1000).toString();
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds.$stringMillis";
  }

  /// Extract the current cover selected by the user, or by default the first one
  Future<File> extractCover({
    double scale = 1.0,
    void Function(Statistics) progressCallback,
  }) async {
    final FlutterFFmpegConfig _config = FlutterFFmpegConfig();
    _config.setLogLevel(LogLevel.AV_LOG_WARNING);
    String timeFormat = _printDuration(_coverTime());
    final String tempPath = (await getTemporaryDirectory()).path;
    final String outputPath =
        tempPath + "/" + _editionName + timeFormat + ".jpg";

    //-----------------//
    //CALCULATE FILTERS//
    //-----------------//
    final String crop = _minCrop == Offset.zero && _maxCrop == Offset(1.0, 1.0)
        ? ""
        : await _getCrop(file.path);
    final String rotation =
        _rotation >= 360 || _rotation <= 0 ? "" : _getRotation();
    final String scaleInstruction =
        scale == 1.0 ? "" : "scale=iw*$scale:ih*$scale";

    //----------------//
    //VALIDATE FILTERS//
    //----------------//
    final List<String> filters = [scaleInstruction, crop, rotation];
    filters.removeWhere((item) => item.isEmpty);
    final String filter = filters.isNotEmpty ? "" + filters.join(",") : "";
    final String execute =
        " -ss $timeFormat -i ${file.path} -y -vf \"$filter\" -frames:v 1 $outputPath -hide_banner -loglevel error";

    if (progressCallback != null)
      _config.enableStatisticsCallback(progressCallback);
    final int code = await _ffmpeg.execute(execute);
    _config.enableStatisticsCallback(null);

    //------//
    //RESULT//s
    //------//
    if (code == 0) {
      print("SUCCESS COVER EXTRACTION AT $outputPath");
      return File(outputPath);
    } else if (code == 255) {
      print("USER CANCEL COVER EXTRACTION");
      return null;
    } else {
      print("ERROR ON COVER EXTRACTION (CODE $code)");
      return null;
    }
  }

  /// Extract all the frames (5 fps) of the trimmed video
  Future<List<dynamic>> extractFrames({
    String format = "mp4",
    double scale = 1.0,
    bool fullFrames = false,
    void Function(Statistics) progressCallback,
    VideoExportPreset preset = VideoExportPreset.none,
  }) async {
    if (_skipFramesExtraction) return null;

    final FlutterFFmpegConfig _config = FlutterFFmpegConfig();
    _config.disableLogs();
    final String videoPath = file.path;
    final Directory localProcessDir = new Directory(_editionTempDir.path +
        DateTime.now().millisecondsSinceEpoch.toString() +
        "/");
    // Create directory if does not exists and delete content if not empty
    if (localProcessDir.existsSync()) {
      await localProcessDir.delete(recursive: true);
    }
    await localProcessDir.create(recursive: true);

    //-----------------//
    //CALCULATE FILTERS//
    //-----------------//
    final String gif = format != "gif" ? "" : "fps=10 -loop 0";
    final String trim = _minTrim == 0.0 && _maxTrim == 1.0 || fullFrames
        ? ""
        : "-ss $_trimStart -to $_trimEnd";
    final String ssTrim = fullFrames ? "" : "-ss $_trimStart";
    final String toTrim = fullFrames ? "" : "-to ${_trimEnd - _trimStart}";

    final String crop = _minCrop == Offset.zero && _maxCrop == Offset(1.0, 1.0)
        ? ""
        : await _getCrop(videoPath);
    final String rotation =
        _rotation >= 360 || _rotation <= 0 ? "" : _getRotation();
    final String scaleInstruction =
        scale == 1.0 ? "" : "scale=iw*$scale:ih*$scale";

    //----------------//
    //VALIDATE FILTERS//
    //----------------//
    final List<String> filters = [crop, scaleInstruction, rotation, gif];
    filters.removeWhere((item) => item.isEmpty);
    final String filter = filters.isNotEmpty ? "" + filters.join(",") : "";

    final String outputPath = localProcessDir.path +
        _editionName +
        _minTrim.toString() +
        _maxTrim.toString() +
        "%03d.jpg";
    // Create a thumbnail image every X seconds of the video: https://trac.ffmpeg.org/wiki/Create%20a%20thumbnail%20image%20every%20X%20seconds%20of%20the%20video
    final String execute =
        " $ssTrim -i $videoPath $toTrim -y -vf \"fps=$_fpsExtraction,$filter\" $outputPath -hide_banner -loglevel error";

    if (progressCallback != null)
      _config.enableStatisticsCallback(progressCallback);
    final int code = await _ffmpeg.execute(execute);
    _config.enableStatisticsCallback(null);

    //------//
    //RESULT//
    //------//
    if (code == 0) {
      print("SUCCESS FRAMES EXTRACTION AT $outputPath");
      return localProcessDir.listSync(followLinks: false);
    } else if (code == 255) {
      print("USER CANCEL FRAMES EXTRACTION");
      return null;
    } else {
      print("ERROR ON FRAMES EXTRACTION (CODE $code)");
      return null;
    }
  }
}
