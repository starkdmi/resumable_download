part of 'package:resumable_download/src/resumable_download_base.dart';

class DownloadController {
  DownloadController._({
    required StreamSubscription? subscription, 
    required DownloadConfig args,
  }) : _subscription = subscription, _args = args {

    final onProgress = args.onProgress;
    args.onProgress = (bytesReceived, totalBytes) {
      _bytesReceived = bytesReceived;
      _totalBytes = totalBytes;
      onProgress?.call(bytesReceived, totalBytes);
    };

    final onDone = args.onDone;
    args.onDone = () {
      _done = true;
      onDone?.call();
    };
  }

  final DownloadConfig _args;
  StreamSubscription? _subscription;
  int _bytesReceived = -1;
  int _totalBytes = -1;

  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  bool _downloading = true;
  bool get isDownloading => _cancelled;

  bool _done = false;
  bool get isDone => _done;

  bool get doneOrCancelled => isDone || _cancelled;

  Future<bool> pause() async {
    if (doneOrCancelled || !_downloading) return false;
    await _subscription?.cancel();
    _downloading = false;
    _args.onPause?.call(_bytesReceived, _totalBytes);
    return true;
  }

  Future<bool> resume() async {
    if (doneOrCancelled || _downloading) return false;
    _subscription = await _download(args: _args, from: _bytesReceived);
    _downloading = true;
    _args.onResume?.call();
    return true;
  }

  Future<bool> cancel() async {
    if (doneOrCancelled) return false;
    // _cancelled = true;
    await _subscription?.cancel();
    _cancelled = true;
    if (_args.deleteOnCancel) {
      await _args.file.delete();
    }
    _args.onCancel?.call();
    return true;
  }
}