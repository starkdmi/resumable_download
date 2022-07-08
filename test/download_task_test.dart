// @Timeout(Duration(seconds: 300))

import 'package:download_task/download_task.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File, Directory;

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
      return streamFile("video.mp4");
    } else if (request.url == links[1]) {
      // final response = http.StreamedResponse(Stream.fromIterable([]), 404);
      // return Future.value(response);
      throw UnimplementedError();
    }
    throw UnimplementedError();
  });

  group("Valid link tests", () {
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
  group("Big video file", () {
    late DownloadTask task;
    final file = File("$downloadDirectory/video.mp4");

    setUp(() async {
      task = await DownloadTask.download(links[1], file: file, client: client);
    });

    tearDown(() async {
      deleteFile(file);
    });

    test("Pause, Resume, Cancel", () async {
      Future.delayed(const Duration(milliseconds: 100)).then((_) => task.pause());
      Future.delayed(const Duration(milliseconds: 200)).then((_) => task.resume());
      Future.delayed(const Duration(milliseconds: 300)).then((_) => task.pause());
      Future.delayed(const Duration(milliseconds: 400)).then((_) => task.resume());
      Future.delayed(const Duration(milliseconds: 500)).then((_) => task.cancel());

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
}

Future<http.StreamedResponse> streamFile(String filename){
  final file = File("$rootDirectory/files/$filename");
  final stream = file.openRead();
  final response = http.StreamedResponse(stream, 200);
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