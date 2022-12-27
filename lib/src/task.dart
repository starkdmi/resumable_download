import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io' show File, FileMode;
import 'package:http/http.dart' as http;

/// Downloading state
enum TaskState { downloading, paused, success, canceled, error }

/// Event representing current progress or error and the current state
class TaskEvent {
  const TaskEvent(
      {required this.state, this.bytesReceived, this.totalBytes, this.error});

  final TaskState state;
  final int? bytesReceived;
  final int? totalBytes;
  final Object? error;

  @override
  String toString() => "TaskEvent ($state)";
}

/// Main class, used as a singletone for initialising the downloads
class DownloadTask {
  DownloadTask._({
    required this.url,
    required this.file,
    required this.headers,
    required this.client,
    required this.deleteOnCancel,
    required this.deleteOnError,
    this.size,
    this.safeRange = false,
  });

  final Uri url;
  final File file;
  final Map<String, String> headers;
  final http.Client client;
  final bool deleteOnCancel;
  final bool deleteOnError;
  final int? size;
  final bool safeRange;

  /// Events stream, used to listen for downloading state changes
  Stream<TaskEvent> get events => _events.stream;

  /// Latest event
  TaskEvent? get event => _event;

  /// Static method to fire file downloading returns future of [DownloadTask] which may be used to control the request
  ///
  /// * [headers] are custom HTTP headers for client, may be used for request authentication
  /// * if [client] is pas null the default one will be used
  /// * [file] is download path, file will be created while downloading
  /// * [deleteOnCancel] specify if file should be deleted after download is cancelled
  /// * [deleteOnError] specify if file should be deleted when error is raised
  /// * [size] used to specify bytes end for range header
  /// * [safeRange] used to skip range header if bytes end not found
  ///
  static Future<DownloadTask> download(
    Uri url, {
    Map<String, String> headers = const {},
    http.Client? client,
    required File file,
    bool deleteOnCancel = true,
    bool deleteOnError = false,
    int? size,
    bool safeRange = false,
  }) async {
    final task = DownloadTask._(
        url: url,
        headers: headers,
        client: client ?? http.Client(),
        file: file,
        deleteOnCancel: deleteOnCancel,
        deleteOnError: deleteOnError,
        size: size,
        safeRange: safeRange);
    await task.resume();
    return task;
  }

  /// Pause file downloading, file will be stored on defined location
  /// downloading may be continued from the paused point if file exists
  Future<bool> pause() async {
    if (_doneOrCancelled || !_downloading) return false;
    await _subscription?.cancel();
    _addEvent(TaskEvent(
        state: TaskState.paused,
        bytesReceived: _bytesReceived,
        totalBytes: _totalBytes));
    return true;
  }

  /// Resume file downloading, if file exists downloading will continue from file size
  /// will return `false` if downloading is in progress, finished or cancelled
  Future<bool> resume() async {
    if (_doneOrCancelled || _downloading) return false;
    // _subscription = await _download();
    _download().then((value) => _subscription = value);
    _addEvent(TaskEvent(
        state: TaskState.downloading,
        bytesReceived: _bytesReceived,
        totalBytes: _totalBytes));
    return true;
  }

  /// Cancel the downloading, if [deleteOnCancel] is `true` then file will be deleted
  /// will return `false` if downloading was already finished or cancelled
  Future<bool> cancel() async {
    if (_doneOrCancelled) return false;
    await _subscription?.cancel();
    _addEvent(TaskEvent(
        state: TaskState.canceled,
        bytesReceived: _bytesReceived,
        totalBytes: _totalBytes));
    _dispose(TaskState.canceled);
    return true;
  }

  // Events stream
  StreamSubscription? _subscription;
  final StreamController<TaskEvent> _events = StreamController<TaskEvent>();
  TaskEvent? _event;

  int _bytesReceived = -1;
  int _totalBytes = -1;

  // Internal shortcuts
  bool get _cancelled => event?.state == TaskState.canceled;
  bool get _downloading => event?.state == TaskState.downloading;
  bool get _done => event?.state == TaskState.success;
  bool get _doneOrCancelled => _done || _cancelled;

  /// Add new event to stream
  void _addEvent(TaskEvent event) {
    _event = event;
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  /// Clean up
  Future<void> _dispose(TaskState state) async {
    if (state == TaskState.canceled) {
      if (deleteOnCancel) {
        await file.delete();
      }
      _events.close();
    } else if (state == TaskState.error) {
      if (deleteOnError) {
        await file.delete();
      }
      _events.close();
    } else if (state == TaskState.success) {
      _events.close();
    }
  }

  /// Download function
  /// returns future of [StreamSubscription] which used to receive updates internally
  /// returns `null` on error
  Future<StreamSubscription?> _download() async {
    late final StreamSubscription subscription;

    Future<void> onError(Object error) async {
      _addEvent(TaskEvent(state: TaskState.error, error: error));
      _dispose(TaskState.error);
    }

    try {
      // calculate starting point
      int from = _bytesReceived;
      if (from == -1) {
        if (await file.exists()) {
          // use existed file bytes count
          from = await file.length();
        } else {
          from = 0;
          await file.create(recursive: false);
        }
      }
      final sink = await file.open(mode: FileMode.writeOnlyAppend);

      final request = http.Request("GET", url);
      
      request.headers.addAll(headers);
      
      // range header
      if (size != null) {
        request.headers["Range"] = "bytes=$from-$size";
      } else {
        if (!safeRange) {
          request.headers["Range"] = "bytes=$from-";
        }
      }

      final response = await client.send(request);

      // length total
      int totalBytes = -1;
      final length = response.contentLength;
      if (length != null) {
        totalBytes = from + length;
      } else {
        // Content-Lenght header is missing, a try to get size from Content-Range header
        final range = response.headers["content-range"];
        if (range != null) {
          final index = range.indexOf("/");
          if (index != -1) {
            final total = int.tryParse(range.substring(index + 1));
            if (total != null) totalBytes = total;
          }
        }
      }

      // process
      subscription = response.stream.listen((data) async {
        subscription.pause();
        await sink.writeFrom(data);
        final bytesReceived = from + data.length;
        from = bytesReceived;
        _bytesReceived = bytesReceived;
        _totalBytes = totalBytes;
        _addEvent(TaskEvent(
            state: TaskState.downloading,
            bytesReceived: bytesReceived,
            totalBytes: totalBytes));
        subscription.resume();
      }, onDone: () async {
        _addEvent(const TaskEvent(state: TaskState.success));
        await sink.close();
        // client.close();
        _dispose(TaskState.success);
      }, onError: onError);

      return subscription;
    } catch (error) {
      await onError(error);
      return null;
    }
  }
}
