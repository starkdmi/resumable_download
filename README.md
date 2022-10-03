**Resumable HTTP download request** - pause, resume, cancel, realtime progress and error handling

## Features

- **Take control** - pause, resume and cancel
- **Listen to updates** - realtime progress and failure handling
- **Pure Dart** - only `http` dependency 
- **Easy to use** - singletone and stream

## Getting started

Include latest version from [pub.dev](https://pub.dev/packages/download_task) to `pubspec.yaml` and simply run
```dart
await DownloadTask.download(url, destination);
```

## Usage

```dart
// initialize download request
final task = await DownloadTask.download(url, File("image.webp"));

// listen to state changes
task.events.listen((event) { ... }

// control task
task.pause();
task.resume();
task.cancel();
```
Example source code available at `/example/download_task_example.dart`

## Additional information

This package is primarly used in [isolated_download_manager](https://pub.dev/packages/isolated_download_manager)
