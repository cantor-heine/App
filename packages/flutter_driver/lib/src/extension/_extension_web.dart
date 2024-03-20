// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:js';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

/// The web implementation of [registerWebServiceExtension].
///
/// Registers Web Service Extension for Flutter Web application.
///
/// window.$flutterDriver will be called by Flutter Web Driver to process
/// Flutter Command.
///
/// See also:
///
///  * [_extension_io.dart], which has the dart:io implementation
void registerWebServiceExtension(Future<Map<String, dynamic>> Function(Map<String, String>) call) {
  // Define the result variable because packages/flutter_driver/lib/src/driver/web_driver.dart
  // checks for this value to become non-null when waiting for the result. If this value is
  // undefined at the time of the check, WebDriver throws an exception.
  context[r'$flutterDriverResult'] = null;

  _window.setProperty(r'$flutterDriver'.toJS, (JSString message) async {
    final Map<String, String> params = Map<String, String>.from(
        jsonDecode(message.toDart) as Map<String, dynamic>);
    final Map<String, dynamic> result = Map<String, dynamic>.from(
        await call(params));
    context[r'$flutterDriverResult'] = json.encode(result);
  }.toJS);
}
