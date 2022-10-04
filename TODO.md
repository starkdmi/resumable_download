
## Support Web platform

Due to using of `dart:io` web is not supported.

There are two code snippets to run the download using browser's UI:
- In the same Tab
```dart
html.AnchorElement anchorElement = html.AnchorElement(
  href: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
);
anchorElement.download = "BigBuckBunny";
anchorElement.click();
```
- New Tab
```dart
html.window.open(
  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", 
  "BigBuckBunny"
);
```

To support all the platforms web implementation should be splitted into different file and imported like:
```dart 
import 'task.dart' 
  if (dart.library.io) 'task_io.dart'
  if (dart.library.html) 'task_browser.dart';
```

Also in Flutter web is detected using `kIsWeb`:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (kIsWeb) {
  // web download code
} else {
  // dart.io
}
```