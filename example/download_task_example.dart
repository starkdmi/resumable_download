import 'package:download_task/download_task.dart';
import 'dart:io' show File, Directory;

void main() async {
  // specify url and destionation
  final url = Uri.parse("https://golang.org/dl/go1.19.1.src.tar.gz");
  final file = File("${Directory.current.path}/example/Go.tar.gz");
  
  // initialize download request
  final task = await DownloadTask.download(url, file: file);

  // listen to state changes
  double previousProgress = 0.0;
  task.events.listen((event) { 
    switch (event.state) {
      case TaskState.downloading:
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

  // control the process
  await Future.delayed(const Duration(milliseconds: 500));
  task.pause();
  await Future.delayed(const Duration(milliseconds: 500));
  task.resume();
  await Future.delayed(const Duration(milliseconds: 1500));
  task.cancel();
}