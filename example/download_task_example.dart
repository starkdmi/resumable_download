import 'package:download_task/download_task.dart';
import 'dart:io' show File;

void main() async {
  final url = Uri.parse(
    // "https://not.found/html.txt",
    "https://golang.org/dl/go1.17.3.src.tar.gz",
  );

  double previousProgress = 0.0;
  final task = await DownloadTask.download(url,
    file: File("/Users/starkdmi/Downloads/test/Go.gz"),
  );
  task.events.listen((event) { 
    switch (event.state) {
      case TaskState.downloading:
        // print(event);
        final bytesReceived = event.bytesReceived!;
        final totalBytes = event.totalBytes!;
        if (totalBytes == -1) return;
        final progress = (bytesReceived / totalBytes * 100).floorToDouble();
        if (progress != previousProgress && progress % 10 == 0) {
          print("progress $progress%");
          previousProgress = progress;
        }
        break;
      case TaskState.paused:
        print("paused");
        break;
      case TaskState.success:
        print("downloaded");
        break;
      case TaskState.canceled:
        print("canceled");
        break;
      case TaskState.error:
        print("error: ${event.error!}");
        break;
    }
  });

  await Future.delayed(const Duration(milliseconds: 500));
  task.pause();//.then((status) => print(status ? "paused2" : "can't pause"));
  // await Future.delayed(const Duration(milliseconds: 500));
  // request.pause().then((status) => print(status ? "paused" : "can't pause"));
  await Future.delayed(const Duration(milliseconds: 500));
  task.resume();//.then((status) => print(status ? "resumed2" : "can't resume"));
  await Future.delayed(const Duration(milliseconds: 1500));
  task.cancel();//.then((status) => print(status ? "cancelled2" : "can't cancell"));
}