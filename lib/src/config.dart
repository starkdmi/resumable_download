part of 'package:resumable_download/src/resumable_download_base.dart';

class DownloadConfig {
  DownloadConfig._({
    required this.url,
    required this.file,
    required this.headers,
    required this.client,
    this.onProgress,
    this.onDone,
    this.onError,
    this.onCancel,
    this.onPause,
    this.onResume,
    required this.deleteOnCancel,
    required this.deleteOnError,
  });

  final Uri url;
  final File file;
  final Map<String, String> headers;
  final http.Client client;

  void Function(int bytesReceived, int totalBytes)? onProgress;
  void Function()? onDone;
  final void Function(Object)? onError;
  final void Function()? onCancel;
  final void Function(int bytesReceived, int totalBytes)? onPause;
  final void Function()? onResume;

  final bool deleteOnCancel;
  final bool deleteOnError;
}