// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_driver/flutter_driver.dart';
import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main(List<String> args) {
  final String testOutputDirectory = getTestOutputDirectory(args);
  macroPerfTest(
    'fading_child_animation_perf',
    kFadingChildAnimationRouteName,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
    testOutputDirectory: testOutputDirectory,
  );
}
