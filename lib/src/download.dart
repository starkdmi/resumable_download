/*import 'dart:async' show StreamSubscription, StreamController;
import 'dart:io' show File, FileMode;
import 'package:http/http.dart' as http;

// part 'package:download_task/src/config.dart';
part 'package:download_task/src/task.dart';

Future<DownloadTask> download({
  required Uri url,
  Map<String, String> headers = const {},
  http.Client? client,
  required File file,
}) async {
  final task = DownloadTask._(
    url: url,
    headers: headers,
    client: client ?? http.Client(),
    file: file,
  );
  await task.resume();
  return task;
}*/