// @Timeout(Duration(seconds: 300))
import 'dart:async';

import 'package:download_task/download_task.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File, Directory;

// Code Coverage
// flutter test --coverage
// genhtml coverage/lcov.info -o coverage/html

final List<Uri> links = [
  Uri.parse("https://download.task/image.png"),
  Uri.parse("https://download.task/video.mp4"),
  Uri.parse("https://download.task/notFound.zip"),
];
String rootDirectory = "${Directory.current.path}/test";
final String downloadDirectory = "$rootDirectory/temp";

void main() {
  final client = MockClient.streaming((request, bodyStream) {
    if (request.url == links[0]) {
      return streamFile("image.png");
    } else if (request.url == links[1]) {
      // return streamRandomBytes(50 * 1024 * 1024);
      return longStream(seconds: 10);
      // return streamFile("video.mp4");
    } else if (request.url == links[2]) {
      // final response = http.StreamedResponse(Stream.fromIterable([]), 404);
      // return Future.value(response);
      throw UnimplementedError();
    }
    throw UnimplementedError();
  });

  group("Valid simple", () {
    late DownloadTask task;
    final file = File("$downloadDirectory/image.png");

    setUp(() async {
      task = await DownloadTask.download(links[0], file: file, client: client);
    });

    tearDown(() async {
      deleteFile(file);
    });

    test("Downloaded", () async {
      final last = await task.events.last;
      expect(last.state, equals(TaskState.success));

      expect(file.existsSync(), equals(true));
    });
  });
  group("Valid with controller", () {
    late DownloadTask task;
    final file = File("$downloadDirectory/video.mp4");

    setUp(() async {
      task = await DownloadTask.download(links[1], file: file, client: client);
    });

    tearDown(() async {
      deleteFile(file);
    });

    test("Pause, Resume, Cancel", () async {
      Future.delayed(const Duration(milliseconds: 150)).then((_) => task.pause());
      Future.delayed(const Duration(milliseconds: 300)).then((_) => task.resume());
      Future.delayed(const Duration(milliseconds: 450)).then((_) => task.pause());
      Future.delayed(const Duration(milliseconds: 600)).then((_) => task.resume());
      Future.delayed(const Duration(milliseconds: 750)).then((_) => task.cancel());

      final events = await task.eventStatesSequence();

      expect(events, equals([
        TaskState.downloading,
        TaskState.paused,
        TaskState.downloading,
        TaskState.paused,
        TaskState.downloading,
        TaskState.canceled,
      ]));
    });
  });
  
  group("Advanced", () {
    late DownloadTask task;
    final file = File("$downloadDirectory/video.mp4");

    setUp(() async {
      // file which already exists
      await file.create();
      final bytes = List.generate(1024, (index) => 100);
      await file.writeAsBytes(bytes);

      task = await DownloadTask.download(links[1], file: file, client: client);
    });

    tearDown(() async {
      deleteFile(file);
    });

    test("Continue downloading when file exists ", () async {
      expect(task.event?.bytesReceived, equals(-1));
      await Future.delayed(const Duration(milliseconds: 900));
      // file exists with 1024 bytes and 3 bytes per second were downloaded
      expect(task.event?.bytesReceived, equals(1027));
    });
  });

  group("Bad link", () {
    late DownloadTask task;
    final file = File("$downloadDirectory/file.zip");

    setUp(() async {
      task = await DownloadTask.download(links[2], file: file, client: client, deleteOnError: true);
    });

    tearDown(() async {
      deleteFile(file);
    });

    test("Should fail", () async {
      await Future.delayed(const Duration(milliseconds: 300));
      final events = await task.events.toList();
      // print(events);
      expect(events.last.state, equals(TaskState.error));      
      expect(file.existsSync(), equals(false));
    });
  });
}

Future<http.StreamedResponse> streamFile(String filename){
  final file = File("$rootDirectory/files/$filename");
  final stream = file.openRead();
  final response = http.StreamedResponse(stream, 200);
  return Future.value(response);
}

// Uint8List(1024)
/*Future<http.StreamedResponse> streamRandomBytes(int length) {
  final list = List.generate(length, (index) => 100);
  final stream = Stream.fromIterable([list]);
  final response = http.StreamedResponse(stream, 200);
  return Future.value(response);
}*/

Future<http.StreamedResponse> longStream({ required int seconds }) {
  final controller = StreamController<List<int>>();
  for (int i = 0; i <= seconds; i++) {
    Future.delayed(Duration(seconds: i))
      .then((_) => controller.add([100, 100, 100]));
  }
  final response = http.StreamedResponse(controller.stream, 200);
  return Future.value(response);
}


Future<void> deleteFile(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}

extension DeduplicateStates on DownloadTask {
  // convert stream of events to states list and remove duplicates (only when appears in a row)
  Future<List<TaskState>> eventStatesSequence() async {
   final eventsList = await events.map((e) => e.state).toList();   
    List<TaskState> uniqueSequence = []; 
    for (int i = 0; i < eventsList.length; i++) {
      final event = eventsList[i];
      if (i == 0) {
        uniqueSequence.add(event);
        continue;
      }
      if (event != eventsList[i-1]) {
        uniqueSequence.add(event);
      }
    }
    return uniqueSequence;
  }
}

extension SkipProgressEvents on Stream<TaskEvent> {
  Stream<TaskEvent> skipDownloading() {
    return skipWhile((e) => e.state == TaskState.downloading);
  }
}