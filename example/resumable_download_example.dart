import 'package:resumable_download/resumable_download.dart' as resumable;
import 'dart:io' show File;

void main() async {
  final url = Uri.parse(
    // "https://not.found/html.txt",
    "https://golang.org/dl/go1.17.3.src.tar.gz",
  );

  double previousProgress = 0.0;
  final request = await resumable.download(
    url: url,
    // headers: { }
    file: File("/Users/starkdmi/Downloads/test/Go.gz"),
    onProgress: (bytesReceived, totalBytes) {
      if (totalBytes == -1) return;
      final progress = (bytesReceived / totalBytes * 100).floorToDouble();
      if (progress != previousProgress && progress % 10 == 0) {
        print("progress $progress%");
        previousProgress = progress;
      }
    },
    onDone: () => print("downloaded"),
    onError: (error) => print("error: $error"),
    onCancel: () => print("onCancel - cancelled"),
    onPause: (bytesReceived, totalBytes) => print("onPause - paused"),
    // deleteOnCancel: true,
    // deleteOnError: true,
  );

  await Future.delayed(const Duration(milliseconds: 500));
  request.pause().then((status) => print(status ? "paused" : "can't pause"));
  // await Future.delayed(const Duration(milliseconds: 500));
  // request.pause().then((status) => print(status ? "paused" : "can't pause"));
  await Future.delayed(const Duration(milliseconds: 500));
  request.resume().then((status) => print(status ? "resumed" : "can't resume"));
  await Future.delayed(const Duration(milliseconds: 1500));
  request.cancel().then((status) => print(status ? "cancelled" : "can't cancell"));
}
