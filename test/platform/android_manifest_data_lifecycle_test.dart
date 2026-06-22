import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest disables app backup restore', () async {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final contents = await manifest.readAsString();

    expect(contents, contains('android:allowBackup="false"'));
    expect(contents, isNot(contains('android:allowBackup="true"')));
  });
}
