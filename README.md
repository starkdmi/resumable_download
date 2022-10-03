**Resumable HTTP download request** - pause, resume, cancel, progress and error handling

## Features

- **Control everything** - pause, resume and cancellation
- **Listen to updates** - realtime progress and failure handling
- **Easy to use**
- **Pure Dart**

## Getting started

Include latest version from [pub.dev](https://pub.dev/packages/download_task) to pubspec.yaml and simply run
```dart
await DownloadTask.download(url, file);
```

## Usage

```dart
// initialize download request
final task = await DownloadTask.download(url, file);

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
