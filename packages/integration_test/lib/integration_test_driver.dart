// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

import 'package:integration_test/src/common.dart';
import 'package:path/path.dart' as path;

/// Flutter Driver test output directory.
///
/// Tests should write any output files to this directory. Defaults to the path
/// set in the FLUTTER_TEST_OUTPUTS_DIR environment variable, or `build` if
/// unset.
String testOutputsDirectory =
    Platform.environment['FLUTTER_TEST_OUTPUTS_DIR'] ?? 'build';

/// The callback type to handle [Response.data] after the test
/// succeeds.
typedef ResponseDataCallback = FutureOr<void> Function(Map<String, dynamic>?);

/// Writes a json-serializable data to
/// [testOutputsDirectory]/`testOutputFilename.json`.
///
/// This is the default `responseDataCallback` in [integrationDriver].
Future<void> writeResponseData(
  Map<String, dynamic>? data, {
  String testOutputFilename = 'integration_response_data',
  String? destinationDirectory,
}) async {
  assert(testOutputFilename != null);
  destinationDirectory ??= testOutputsDirectory;
  await fs.directory(destinationDirectory).create(recursive: true);
  final File file = fs.file(path.join(
    destinationDirectory,
    '$testOutputFilename.json',
  ));
  final String resultString = _encodeJson(data, true);
  await file.writeAsString(resultString);
}

/// Adaptor to run an integration test using `flutter drive`.
///
/// To an integration test `<test_name>.dart` using `flutter drive`, put a file named
/// `<test_name>_test.dart` in the app's `test_driver` directory:
///
/// ```dart
/// import 'dart:async';
///
/// import 'package:integration_test/integration_test_driver.dart';
///
/// Future<void> main() async => integrationDriver();
///
/// ```
///
/// ## Parameters:
///
/// `timeout` controls the longest time waited before the test ends.
/// It is not necessarily the execution time for the test app: the test may
/// finish sooner than the `timeout`.
///
/// `responseDataCallback` is the handler for processing [Response.data].
/// The default value is `writeResponseData`.
///
/// `onScreenshot` can be used to process the screenshots taken during the test.
/// An example could be that this callback compares the byte array against a baseline image,
/// and it return `true` if both images are equal.
///
/// As a result, returning `false` from `onScreenshot` will make the test fail.
Future<void> integrationDriver({
  Duration timeout = const Duration(minutes: 20),
  ResponseDataCallback? responseDataCallback = writeResponseData,
  ScreenshotCallback? onScreenshot,
}) async {
  final FlutterDriver driver = await FlutterDriver.connect();
  final String jsonResult = await driver.requestData(null, timeout: timeout);
  final Response response = Response.fromJson(jsonResult);

  if (onScreenshot != null) {
    final List<dynamic> screenshots = response.data!['screenshots'] as List<dynamic>;
    for (final dynamic screenshot in screenshots) {
      final Map<String, dynamic> data = screenshot as Map<String, dynamic>;
      final List<dynamic> screenshotBytes = data['bytes'] as List<dynamic>;
      final String screenshotName = data['screenshotName'] as String;

      bool ok = false;
      try {
        ok = await onScreenshot(screenshotName, screenshotBytes.cast<int>());
      } catch (exception) {
        throw StateError('Screenshot failure:\n'
            'onScreenshot("$screenshotName", <bytes>) threw an exception: $exception');
      }
      if (!ok) {
        throw StateError('Screenshot failure:\n'
            'Expected onScreenshot("$screenshotName", <bytes>) to return true, but it returned false');
      }
    }
  }

  await driver.close();

  if (response.allTestsPassed) {
    print('All tests passed.');
    if (responseDataCallback != null) {
      await responseDataCallback(response.data);
    }
    exit(0);
  } else {
    print('Failure Details:\n${response.formattedFailureDetails}');
    exit(1);
  }
}

const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

String _encodeJson(Map<String, dynamic>? jsonObject, bool pretty) {
  return pretty ? _prettyEncoder.convert(jsonObject) : json.encode(jsonObject);
}
