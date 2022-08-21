import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io' show File, FileMode;
import 'package:http/http.dart' as http;

enum TaskState {
  downloading, paused, success, canceled, error
}

class TaskEvent {
  const TaskEvent({ required this.state, this.bytesReceived, this.totalBytes, this.error });

  final TaskState state;
  final int? bytesReceived;
  final int? totalBytes;
  final Object? error;

  @override
  String toString() => "TaskEvent ($state)";
}

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

  Stream<TaskEvent> get events => _events.stream;
  TaskEvent? get event => _event;

  static Future<DownloadTask> download(Uri url, {
    Map<String, String> headers = const {},
    http.Client? client,
    required File file,
    bool deleteOnCancel = true,
    bool deleteOnError = false,
    int? size, // used to specify bytes end for range header
    bool safeRange = false, // used to skip range header if bytes end not found
  }) async {
    final task = DownloadTask._(
      url: url,
      headers: headers,
      client: client ?? http.Client(),
      file: file,
      deleteOnCancel: deleteOnCancel,
      deleteOnError: deleteOnError,
      size: size,
      safeRange: safeRange
    );
    await task.resume();
    return task;
  }

  Future<bool> pause() async {
    if (_doneOrCancelled || !_downloading) return false;
    await _subscription?.cancel();
    _addEvent(TaskEvent(state: TaskState.paused, bytesReceived: _bytesReceived, totalBytes: _totalBytes));
    return true;
  }

  Future<bool> resume() async {
    if (_doneOrCancelled || _downloading) return false;
    _subscription = await _download();
    _addEvent(TaskEvent(state: TaskState.downloading, bytesReceived: _bytesReceived, totalBytes: _totalBytes));
    return true;
  }

  Future<bool> cancel() async {
    if (_doneOrCancelled) return false;
    await _subscription?.cancel();
    _addEvent(TaskEvent(state: TaskState.canceled, bytesReceived: _bytesReceived, totalBytes: _totalBytes));
    _dispose(TaskState.canceled);
    return true;
  }

  StreamSubscription? _subscription;
  final StreamController<TaskEvent> _events = StreamController<TaskEvent>();
  TaskEvent? _event;
  
  int _bytesReceived = -1;
  int _totalBytes = -1;

  bool get _cancelled => event?.state == TaskState.canceled;
  bool get _downloading => event?.state == TaskState.downloading;
  bool get _done => event?.state == TaskState.success;
  bool get _doneOrCancelled => _done || _cancelled;

  void _addEvent(TaskEvent event) {
    _event = event;
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

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
        // Content-Lenght header is missing, but sometimes we can get size from Content-Range header
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
      subscription = response.stream.listen(
        (data) async {
          subscription.pause();
          await sink.writeFrom(data); 
          final bytesReceived = from + data.length;
          from = bytesReceived;
          _bytesReceived = bytesReceived;
          _totalBytes = totalBytes;
          _addEvent(TaskEvent(state: TaskState.downloading, bytesReceived: bytesReceived, totalBytes: totalBytes));
          subscription.resume();
        },
        onDone: () async {
          _addEvent(const TaskEvent(state: TaskState.success));
          await sink.close();
          // client.close();
          _dispose(TaskState.success);
        },
        onError: onError
      );

      return subscription;
    } catch (error) {
      await onError(error);
      return null;
    }
  }
}