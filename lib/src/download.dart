import 'dart:async' show StreamSubscription;
import 'dart:io' show File, FileMode;
import 'package:http/http.dart' as http;

part 'package:resumable_download/src/config.dart';
part 'package:resumable_download/src/controller.dart';

Future<DownloadController> download({
  required Uri url,
  Map<String, String> headers = const {},
  http.Client? client,
  required File file,
  void Function(int bytesReceived, int totalBytes)? onProgress,
  void Function()? onDone,
  void Function(Object)? onError,
  void Function()? onCancel,
  void Function(int bytesReceived, int totalBytes)? onPause,
  void Function()? onResume,
  bool deleteOnCancel = true,
  bool deleteOnError = true,
}) async {
  final args = DownloadConfig._(
    url: url,
    headers: headers,
    client: client ?? http.Client(),
    file: file,
    onProgress: onProgress,
    onDone: onDone,
    onError: onError,
    onCancel: onCancel,
    onPause: onPause,
    onResume: onResume,
    deleteOnCancel: deleteOnCancel,
    deleteOnError: deleteOnError,
  );
  final subscription = await _download(args: args);
  return DownloadController._(
    subscription: subscription, 
    args: args
  );
}

Future<StreamSubscription?> _download({ 
  required DownloadConfig args,
  int from = -1,
}) async {
  late final StreamSubscription subscription;
  final onError = args.onError;
  try {
    // calculate starting point
    if (from == -1) {
      if (await args.file.exists()) {
        // use existed file bytes count
        from = await args.file.length();
      } else {
        from = 0;
        await args.file.create(recursive: false);
      }
    }
    final sink = await args.file.open(mode: FileMode.writeOnlyAppend);

    final request = http.Request("GET", args.url)
      ..headers["Range"] = "bytes=$from-";
    final response = await args.client.send(request);

    final length = response.contentLength;
    final totalBytes = length != null ? from + length : -1;

    // process
    subscription = response.stream.listen(
      (data) async {
        subscription.pause();
        await sink.writeFrom(data); 
        final bytesReceived = from + data.length;
        from = bytesReceived;
        args.onProgress?.call(bytesReceived, totalBytes);
        subscription.resume();
      },
      onDone: () async {
        args.onDone?.call();
        await sink.close();
        // args.client.close();
      },
      onError: (error) => onError?.call(error)
    );

    return subscription;
  } catch (error) {
    if (args.deleteOnError) {
      await args.file.delete();
    }

    if (onError != null) {
      onError.call(error);
      return null;
    } else {
      rethrow;
    }
  }
}