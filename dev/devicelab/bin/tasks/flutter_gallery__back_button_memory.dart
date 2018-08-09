// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Measure application memory usage after pausing and resuming the app
/// with the Android back button.

import 'dart:async';

import 'package:flutter_devicelab/framework/adb.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

const String packageName = 'io.flutter.demo.gallery';
const String activityName = 'io.flutter.demo.gallery.MainActivity';

class BackButtonMemoryTest extends MemoryTest {
  BackButtonMemoryTest() : super('${flutterDirectory.path}/examples/flutter_gallery', 'test_memory/back_button.dart', packageName);

  @override
  AndroidDevice get device => super.device;

  /// Perform a series of back button suspend and resume cycles.
  @override
  Future<void> useMemory() async {
    await launchApp();
    await recordStart();
    for (int iteration = 0; iteration < 10; iteration += 1) {
      print('back/forward iteration $iteration');

      // Push back button, wait for it to be seen by the Flutter app.
      prepareForNextMessage('AppLifecycleState.paused');
      await device.shellExec('input', <String>['keyevent', 'KEYCODE_BACK']);
      await receivedNextMessage;

      // Give Android time to settle (e.g. run GCs) after closing the app.
      await new Future<Null>.delayed(const Duration(milliseconds: 100));

      // Relaunch the app, wait for it to launch.
      prepareForNextMessage('READY');
      final String output = await device.shellEval('am', <String>['start', '-n', '$packageName/$activityName']);
      print('adb shell am start: $output');
      if (output.contains('Error'))
        fail('unable to launch activity');
      await receivedNextMessage;

      // Wait for the Flutter app to settle (e.g. run GCs).
      await new Future<Null>.delayed(const Duration(milliseconds: 100));
    }
    await recordEnd();
  }
}

Future<Null> main() async {
  deviceOperatingSystem = DeviceOperatingSystem.android;
  await task(new BackButtonMemoryTest().run);
}
