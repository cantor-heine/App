// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gallery/gallery/demos.dart';
import 'package:e2e/e2e.dart';
import 'package:flutter_gallery/gallery/app.dart' show GalleryApp;

import 'util.dart' show watchPerformance;

// Demos for which timeline data will be collected using
// FlutterDriver.traceAction().
//
// Warning: The number of tests executed with timeline collection enabled
// significantly impacts heap size of the running app. When run with
// --trace-startup, as we do in this test, the VM stores trace events in an
// endless buffer instead of a ring buffer.
//
// These names must match GalleryItem titles from kAllGalleryDemos
// in dev/integration_tests/flutter_gallery/lib/gallery/demos.dart
const List<String> kProfiledDemos = <String>[
  'Shrine@Studies',
  'Contact profile@Studies',
  'Animation@Studies',
  'Bottom navigation@Material',
  'Buttons@Material',
  'Cards@Material',
  'Chips@Material',
  'Dialogs@Material',
  'Pickers@Material',
];

// There are 3 places where the Gallery demos are traversed.
// 1- In widget tests such as dev/integration_tests/flutter_gallery/test/smoke_test.dart
// 2- In driver tests such as dev/integration_tests/flutter_gallery/test_driver/transitions_perf_test.dart
// 3- In on-device instrumentation tests such as dev/integration_tests/flutter_gallery/test/live_smoketest.dart
//
// If you change navigation behavior in the Gallery or in the framework, make
// sure all 3 are covered.

// Demos that will be backed out of within FlutterDriver.runUnsynchronized();
//
// These names must match GalleryItem titles from kAllGalleryDemos
// in dev/integration_tests/flutter_gallery/lib/gallery/demos.dart
const List<String> kUnsynchronizedDemos = <String>[
  'Progress indicators@Material',
  'Activity Indicator@Cupertino',
  'Video@Media',
];

const List<String> kSkippedDemos = <String>[];

// All of the gallery demos, identified as "title@category".
//
// These names are reported by the test app, see _handleMessages()
// in transitions_perf.dart.
List<String> _allDemos = kAllGalleryDemos
    .map(
      (GalleryDemo demo) => '${demo.title}@${demo.category.name}',
    )
    .toList();

/// Scrolls each demo menu item into view, launches it, then returns to the
/// home screen twice.
Future<void> runDemos(List<String> demos, WidgetTester tester) async {
  final Finder demoList = find.byType(Scrollable);
  String currentDemoCategory;

  for (final String demo in demos) {
    if (kSkippedDemos.contains(demo))
      continue;

    final String demoName = demo.substring(0, demo.indexOf('@'));
    final String demoCategory = demo.substring(demo.indexOf('@') + 1);
    print('> $demo');
    await tester.binding.delayed(const Duration(milliseconds: 250));

    if (currentDemoCategory == null) {
      await tester.tap(find.text(demoCategory));
      await tester.pumpAndSettle();
    } else if (currentDemoCategory != demoCategory) {
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(demoCategory));
      await tester.pumpAndSettle();
      // Scroll back to the top
      await tester.drag(demoList, const Offset(0.0, 10000.0));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }
    currentDemoCategory = demoCategory;

    final Finder demoItem = find.text(demoName);
    await tester.scrollUntilVisible(demoItem, demoList, 48.0);
    await tester.pumpAndSettle();

    for (int i = 0; i < 2; i += 1) {
      await tester.tap(demoItem); // Launch the demo

      if (kUnsynchronizedDemos.contains(demo)) {
        // These tests have animation, pumpAndSettle cannot be used.
        // This time is questionable. 300ms is the tested reasonable result.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pageBack();
      } else {
        await tester.pumpAndSettle();
        await tester.pageBack();
      }
      await tester.pumpAndSettle();
    }

    print('< Success');
  }

  // Return to the home screen
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

void main([List<String> args = const <String>[]]) {
  final bool withSemantics = args.contains('--with_semantics');
  final E2EWidgetsFlutterBinding binding =
      E2EWidgetsFlutterBinding.ensureInitialized() as E2EWidgetsFlutterBinding;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  group('flutter gallery transitions on e2e', () {
    testWidgets('find.bySemanticsLabel', (WidgetTester tester) async {
      runApp(const GalleryApp(testMode: true));
      await tester.pumpAndSettle();
      final int id = tester.getSemantics(find.bySemanticsLabel('Material')).id;
      expect(id, greaterThan(-1));
    }, skip: !withSemantics, semanticsEnabled: true);

    testWidgets(
      'all demos',
      (WidgetTester tester) async {
        runApp(const GalleryApp(testMode: true));
        await tester.pumpAndSettle();
        // Collect timeline data for just a limited set of demos to avoid OOMs.
        await watchPerformance(binding, () async {
          await runDemos(kProfiledDemos, tester);
        });

        // TODO(CareF): implement transition counting
        // Save the duration (in microseconds) of the first timeline Frame event
        // that follows a 'Start Transition' event. The Gallery app adds a
        // 'Start Transition' event when a demo is launched (see GalleryItem).
        // await summary.writeSummaryToFile('transitions', pretty: true);
        // final String histogramPath = path.join(testOutputsDirectory, 'transition_durations.timeline.json');
        // await saveDurationsHistogram(
        // List<Map<String, dynamic>>.from(timeline.json['traceEvents'] as List<dynamic>),
        // histogramPath);

        // Execute the remaining tests.
        final Set<String> unprofiledDemos = Set<String>.from(_allDemos)
          ..removeAll(kProfiledDemos);
        await runDemos(unprofiledDemos.toList(), tester);
      },
      timeout: const Timeout(Duration(minutes: 5)),
      semanticsEnabled: withSemantics,
    );
  });
}
