// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

class _Test {
  final String name;
  final void Function(WidgetTester tester) body;
  final int notDisposedTotal;
  final int notGCedTotal;
  final int notDisposedInHelpers;
  final int notGCedInHelpers;

  _Test({
    required this.name,
    required this.body,
    this.notDisposedTotal = 0,
    this.notGCedTotal = 0,
    this.notDisposedInHelpers = 0,
    this.notGCedInHelpers = 0,
  });

  /// Verifies [allLeaks] contain expected number of leaks for the test [testDescription].
  void _verifyLeaks(Leaks allLeaks, String testDescription, LeakTesting settings) {
    final Leaks testLeaks = Leaks(
      allLeaks.byType.map(
        (LeakType key, List<LeakReport> value) =>
            MapEntry<LeakType, List<LeakReport>>(key, value.where((LeakReport leak) => leak.phase == testDescription).toList()),
      ),
    );

    for (final LeakType type in expectedContextKeys.keys) {
      final List<LeakReport> leaks = testLeaks.byType[type] ?? <LeakReport>[];
      final List<String> expectedKeys = expectedContextKeys[type]!..sort();
      for (final LeakReport leak in leaks) {
        final List<String> actualKeys = leak.context?.keys.toList() ?? <String>[];
        expect(actualKeys..sort(), equals(expectedKeys), reason: '$testDescription, $type');
      }
    }

    _verifyLeakList(
      testLeaks.notDisposed,
      notDisposed,
      name,
    );
    _verifyLeakList(
      testLeaks.notGCed,
      notGCed,
      testDescription,
    );
  }

  void _verifyLeakList(
  List<LeakReport> list,
  int expectedCount,
  String testDescription,
) {
  expect(list.length, expectedCount, reason: testDescription);

  for (final LeakReport leak in list) {
    expect(leak.trackedClass, contains(InstrumentedDisposable.library));
    expect(leak.trackedClass, contains('$InstrumentedDisposable'));
  }
}
}


final _tests = <String, _Test>{
  "":_Test(
    name: 'group, leaks',
    body: (WidgetTester tester) {

})
};

late final String _test1TrackingOnNoLeaks;
late final String _test2TrackingOffLeaks;
late final String _test3TrackingOnLeaks;
late final String _test4TrackingOnWithCreationStackTrace;
late final String _test5TrackingOnWithDisposalStackTrace;
late final String _test6TrackingOnNoLeaks;
late final String _test7TrackingOnNoLeaks;
late final String _test8TrackingOnNotDisposed;
late final String _test9TrackingOnAsyncPump;
late final String _test10TrackingOnPump;


void main() {
  LeakTesting.collectedLeaksReporter = (Leaks leaks) => _verifyLeaks(leaks);
  LeakTesting.enable();

  LeakTesting.settings = LeakTesting.settings
  .withTrackedAll()
  .withTracked(allNotDisposed: true, allNotGCed: true)
  .withIgnored(createdByTestHelpers: true);

  group('Groups are handled', () {
    testWidgets('test', (_) async {
      StatelessLeakingWidget();
    });
  });

  testWidgets(_test1TrackingOnNoLeaks = 'test1, tracking-on, no leaks', (WidgetTester widgetTester) async {
    _verifyTestIsLeakTracked(_test1TrackingOnNoLeaks);
    await widgetTester.pumpWidget(Container());
  });

  testWidgets(
    _test2TrackingOffLeaks = 'test2, tracking-off, leaks',
    experimentalLeakTesting: LeakTesting.settings.withIgnoredAll(),
  (WidgetTester widgetTester) async {
    expect(LeakTracking.isStarted, true);
    expect(LeakTracking.phase.name, null);
    expect(LeakTracking.phase.ignoreLeaks, true);
    await widgetTester.pumpWidget(StatelessLeakingWidget());
  });

  testWidgets(_test3TrackingOnLeaks = 'test3, tracking-on, leaks', (WidgetTester widgetTester) async {
    _verifyTestIsLeakTracked(_test3TrackingOnLeaks);
    await widgetTester.pumpWidget(StatelessLeakingWidget());

  });

  testWidgets(
    _test4TrackingOnWithCreationStackTrace = 'test4, tracking-on, with creation stack trace',
    experimentalLeakTesting: LeakTesting.settings.withCreationStackTrace(),
  (WidgetTester widgetTester) async {
      _verifyTestIsLeakTracked(_test4TrackingOnWithCreationStackTrace);
      await widgetTester.pumpWidget(StatelessLeakingWidget());
    },
  );

  testWidgets(
    _test5TrackingOnWithDisposalStackTrace = 'test5, tracking-on, with disposal stack trace',
  experimentalLeakTesting: LeakTesting.settings.withDisposalStackTrace(),
    (WidgetTester widgetTester) async {
      _verifyTestIsLeakTracked(_test5TrackingOnWithDisposalStackTrace);
      await widgetTester.pumpWidget(StatelessLeakingWidget());
    },
  );

  testWidgets(_test6TrackingOnNoLeaks = 'test6, tracking-on, no leaks', (_) async {
    _verifyTestIsLeakTracked(_test6TrackingOnNoLeaks);
    InstrumentedDisposable().dispose();
  });

  testWidgets(_test7TrackingOnNoLeaks = 'test7, tracking-on, tear down, no leaks', (_) async {
    _verifyTestIsLeakTracked(_test7TrackingOnNoLeaks);
    final InstrumentedDisposable myClass = InstrumentedDisposable();
    addTearDown(myClass.dispose);
  });

  testWidgets(_test8TrackingOnNotDisposed = 'test8, tracking-on, not disposed leak', (_) async {
    _verifyTestIsLeakTracked(_test8TrackingOnNotDisposed);
    InstrumentedDisposable();
  });

  testWidgets(_test9TrackingOnAsyncPump = 'test9, tracking-on, runAsync and pumpWidget are not test helpers', (WidgetTester tester) async {
    _verifyTestIsLeakTracked(_test9TrackingOnAsyncPump);
    await tester.runAsync(() async {
      await tester.pumpWidget(StatelessLeakingWidget());
    });
  });

  testWidgets(_test10TrackingOnPump = 'test10, tracking-on, pumpWidget is not test helper', (WidgetTester tester) async {
    _verifyTestIsLeakTracked(_test10TrackingOnPump);
    await tester.pumpWidget(StatelessLeakingWidget());
  });
}

void _verifyTestIsLeakTracked(String testName) {
  expect(LeakTracking.isStarted, true);
  expect(LeakTracking.phase.name, testName);
  expect(LeakTracking.phase.ignoreLeaks, false);
}

int _leakReporterInvocationCount = 0;

void _verifyLeaks(Leaks leaks) {
  _leakReporterInvocationCount += 1;
  expect(_leakReporterInvocationCount, 1);

  try {
    expect(leaks, isLeakFree);
  } on TestFailure catch (e) {
    expect(e.message, contains('https://github.com/dart-lang/leak_tracker'));

    expect(e.message, isNot(contains(_test1TrackingOnNoLeaks)));
    expect(e.message, isNot(contains(_test2TrackingOffLeaks)));
    expect(e.message, contains('test: $_test3TrackingOnLeaks'));
    expect(e.message, contains('test: $_test4TrackingOnWithCreationStackTrace'));
    expect(e.message, contains('test: $_test5TrackingOnWithDisposalStackTrace'));
    expect(e.message, isNot(contains(_test6TrackingOnNoLeaks)));
    expect(e.message, isNot(contains(_test7TrackingOnNoLeaks)));
    expect(e.message, contains('test: $_test8TrackingOnNotDisposed'));
    expect(e.message, contains('test: $_test9TrackingOnAsyncPump'));
    expect(e.message, contains('test: $_test10TrackingOnPump'));
  }

  // _verifyLeaksForTest(
  //   leaks,
  //   _test3TrackingOnLeaks,
  //   notDisposed: 1,
  //   notGCed: 1,
  //   expectedContextKeys: <LeakType, List<String>>{
  //     LeakType.notGCed: <String>[],
  //     LeakType.notDisposed: <String>[],
  //   },
  // );
  // _verifyLeaksForTest(
  //   leaks,
  //   _test4TrackingOnWithCreationStackTrace,
  //   notDisposed: 1,
  //   notGCed: 1,
  //   expectedContextKeys: <LeakType, List<String>>{
  //     LeakType.notGCed: <String>['start'],
  //     LeakType.notDisposed: <String>['start'],
  //   },
  // );
  // _verifyLeaksForTest(
  //   leaks,
  //   _test5TrackingOnWithDisposalStackTrace,
  //   notDisposed: 1,
  //   notGCed: 1,
  //   expectedContextKeys: <LeakType, List<String>>{
  //     LeakType.notGCed: <String>['disposal'],
  //     LeakType.notDisposed: <String>[],
  //   },
  // );
  // _verifyLeaksForTest(
  //   leaks,
  //   _test8TrackingOnNotDisposed,
  //   notDisposed: 1,
  //   expectedContextKeys: <LeakType, List<String>>{
  //     LeakType.notGCed: <String>[],
  //     LeakType.notDisposed: <String>[],
  //   },
  // );
  // _verifyLeaksForTest(
  //   leaks,
  //   _test9TrackingOnAsyncPump,
  //   notDisposed: 1,
  //   notGCed: 1,
  //   expectedContextKeys: <LeakType, List<String>>{
  //     LeakType.notGCed: <String>[],
  //     LeakType.notDisposed: <String>[],
  //   },
  // );
  //   _verifyLeaksForTest(
  //   leaks,
  //   _test10TrackingOnPump,
  //   notDisposed: 1,
  //   notGCed: 1,
  //   expectedContextKeys: <LeakType, List<String>>{
  //     LeakType.notGCed: <String>[],
  //     LeakType.notDisposed: <String>[],
  //   },
  // );
}


