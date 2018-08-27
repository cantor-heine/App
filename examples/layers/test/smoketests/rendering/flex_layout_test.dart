// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

import '../../../rendering/flex_layout.dart' as demo;

void main() {
  test('layers smoketest for rendering/flex_layout.dart', () {
    FlutterError.onError = (FlutterErrorDetails details) { throw details.exception; };
    demo.main();
  });
}
