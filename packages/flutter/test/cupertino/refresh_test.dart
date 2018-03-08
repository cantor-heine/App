// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  MockHelper mockHelper;
  Completer<void> refreshCompleter;
  Widget refreshIndicator;

  setUp(() {
    mockHelper = new MockHelper();
    refreshCompleter = new Completer<void>.sync();
    refreshIndicator = new Container();

    when(mockHelper.builder).thenReturn(
      (
        BuildContext context,
        RefreshIndicatorMode refreshState,
        double pulledExtent,
        double refreshTriggerPullDistance,
        double refreshIndicatorExtent,
      ) {
        if (refreshState == RefreshIndicatorMode.inactive) {
          throw new TestFailure(
            'RefreshControlIndicatorBuilder should never be called with the '
            "inactive state because there's nothing to build in that case"
          );
        }
        if (pulledExtent < 0.0) {
          throw new TestFailure('The pulledExtent should never be less than 0.0');
        }
        if (refreshTriggerPullDistance < 0.0) {
          throw new TestFailure('The refreshTriggerPullDistance should never be less than 0.0');
        }
        if (refreshIndicatorExtent < 0.0) {
          throw new TestFailure('The refreshIndicatorExtent should never be less than 0.0');
        }
        // This closure is now shadowing the mock implementation which logs.
        // Pass the call to the mock to log.
        mockHelper.builder(
          context,
          refreshState,
          pulledExtent,
          refreshTriggerPullDistance,
          refreshIndicatorExtent,
        );
        return refreshIndicator;
      },
    );
    // Make the function reference itself concrete.
    when(mockHelper.refreshTask).thenReturn(() => mockHelper.refreshTask());
    when(mockHelper.refreshTask()).thenReturn(refreshCompleter.future);
  });

  SliverList buildAListOfStuff() {
    return new SliverList(
      delegate: new SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return new Container(
            height: 200.0,
            child: new Center(child: new Text(index.toString())),
          );
        },
        childCount: 20,
      ),
    );
  }

  group('UI tests', () {
    testWidgets("doesn't invoke anything without user interaction", (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      // The function is referenced once while passing into CupertinoRefreshControl
      // but never called.
      verify(mockHelper.builder);
      verifyNoMoreInteractions(mockHelper);

      expect(
        tester.getTopLeft(find.widgetWithText(Container, '0')),
        const Offset(0.0, 0.0),
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('calls the indicator builder when starting to overscroll', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      // Drag down but not enough to trigger the refresh.
      await tester.drag(find.text('0'), const Offset(0.0, 50.0));
      await tester.pump();

      // The function is referenced once while passing into CupertinoRefreshControl
      // but never called.
      verify(mockHelper.builder);
      verify(mockHelper.builder(
        any,
        RefreshIndicatorMode.drag,
        50.0,
        100.0, // Default value.
        65.0, // Default value.
      ));
      verifyNoMoreInteractions(mockHelper);

      expect(
        tester.getTopLeft(find.widgetWithText(Container, '0')),
        const Offset(0.0, 50.0),
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      "don't call the builder if overscroll doesn't move slivers like on Android",
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          new Directionality(
            textDirection: TextDirection.ltr,
            child: new CustomScrollView(
              slivers: <Widget>[
                new CupertinoRefreshControl(
                  builder: mockHelper.builder,
                ),
                buildAListOfStuff(),
              ],
            ),
          ),
        );

        // Drag down but not enough to trigger the refresh.
        await tester.drag(find.text('0'), const Offset(0.0, 50.0));
        await tester.pump();

        // The function is referenced once while passing into CupertinoRefreshControl
        // but never called.
        verify(mockHelper.builder);
        verifyNoMoreInteractions(mockHelper);

        expect(
          tester.getTopLeft(find.widgetWithText(Container, '0')),
          const Offset(0.0, 0.0),
        );

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('let the builder update as cancelled drag scrolls away', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      // Drag down but not enough to trigger the refresh.
      await tester.drag(find.text('0'), const Offset(0.0, 50.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(seconds: 3));

      verifyInOrder(<void>[
        mockHelper.builder,
        mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          50.0,
          100.0, // Default value.
          65.0, // Default value.
        ),
        mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          argThat(moreOrLessEquals(48.36801747187993)),
          100.0, // Default value.
          65.0, // Default value.
        ),
        mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          argThat(moreOrLessEquals(44.63031931875867)),
          100.0, // Default value.
          65.0, // Default value.
        ),
        // The builder isn't called again when the sliver completely goes away.
      ]);
      verifyNoMoreInteractions(mockHelper);

      expect(
        tester.getTopLeft(find.widgetWithText(Container, '0')),
        const Offset(0.0, 0.0),
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('drag past threshold triggers refresh task', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final List<MethodCall> platformCallLog = <MethodCall>[];

      SystemChannels.platform.setMockMethodCallHandler((MethodCall methodCall) async {
        platformCallLog.add(methodCall);
      });

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
                onRefresh: mockHelper.refreshTask,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(const Offset(0.0, 0.0));
      await gesture.moveBy(const Offset(0.0, 99.0));
      await tester.pump();
      await gesture.moveBy(const Offset(0.0, -30.0));
      await tester.pump();
      await gesture.moveBy(const Offset(0.0, 50.0));
      await tester.pump();

      verifyInOrder(<void>[
        mockHelper.builder,
        mockHelper.refreshTask,
        mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          99.0,
          100.0, // Default value.
          65.0, // Default value.
        ),
        mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          argThat(moreOrLessEquals(86.78169)),
          100.0, // Default value.
          65.0, // Default value.
        ),
        mockHelper.builder(
          any,
          RefreshIndicatorMode.armed,
          argThat(moreOrLessEquals(105.80452021305739)),
          100.0, // Default value.
          65.0, // Default value.
        ),
        // The refresh callback is triggered after the frame.
        mockHelper.refreshTask(),
      ]);
      verifyNoMoreInteractions(mockHelper);

      expect(
        platformCallLog.last,
        isMethodCall('HapticFeedback.vibrate', arguments: 'HapticFeedbackType.mediumImpact'),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'refreshing task keeps the sliver expanded forever until done',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          new Directionality(
            textDirection: TextDirection.ltr,
            child: new CustomScrollView(
              slivers: <Widget>[
                new CupertinoRefreshControl(
                  builder: mockHelper.builder,
                  onRefresh: mockHelper.refreshTask,
                ),
                buildAListOfStuff(),
              ],
            ),
          ),
        );

        await tester.drag(find.text('0'), const Offset(0.0, 150.0));
        await tester.pump();
        // Let it start snapping back.
        await tester.pump(const Duration(milliseconds: 50));

        verifyInOrder(<void>[
          mockHelper.builder,
          mockHelper.refreshTask,
          mockHelper.builder(
            any,
            RefreshIndicatorMode.armed,
            150.0,
            100.0, // Default value.
            65.0, // Default value.
          ),
          mockHelper.refreshTask(),
          mockHelper.builder(
            any,
            RefreshIndicatorMode.armed,
            argThat(moreOrLessEquals(127.10396988577114)),
            100.0, // Default value.
            65.0, // Default value.
          ),
        ]);

        // Reaches refresh state and sliver's at 65.0 in height after a while.
        await tester.pump(const Duration(seconds: 1));
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.refresh,
          65.0,
          100.0, // Default value.
          65.0, // Default value.
        ));

        // Stays in that state forever until future completes.
        await tester.pump(const Duration(seconds: 1000));
        verifyNoMoreInteractions(mockHelper);
        expect(
          tester.getTopLeft(find.widgetWithText(Container, '0')),
          const Offset(0.0, 65.0),
        );

        refreshCompleter.complete(null);
        await tester.pump();

        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.done,
          65.0,
          100.0, // Default value.
          65.0, // Default value.
        ));
        verifyNoMoreInteractions(mockHelper);

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('expanded refreshing sliver scrolls normally', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      refreshIndicator = const Center(child: const Text('-1'));

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
                onRefresh: mockHelper.refreshTask,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      await tester.drag(find.text('0'), const Offset(0.0, 150.0));
      await tester.pump();

      verify(mockHelper.builder(
        any,
        RefreshIndicatorMode.armed,
        150.0,
        100.0, // Default value.
        65.0, // Default value.
      ));

      // Given a box constraint of 150, the Center will occupy all that height.
      expect(
        tester.getRect(find.widgetWithText(Center, '-1')),
        new Rect.fromLTRB(0.0, 0.0, 800.0, 150.0),
      );

      await tester.drag(find.text('0'), const Offset(0.0, -300.0));
      await tester.pump();

      // Refresh indicator still being told to layout the same way.
      verify(mockHelper.builder(
        any,
        RefreshIndicatorMode.refresh,
        65.0,
        100.0, // Default value.
        65.0, // Default value.
      ));

      // Now the sliver is scrolled off screen.
      expect(
        tester.getTopLeft(find.widgetWithText(Center, '-1')).dy,
        moreOrLessEquals(-180.38461538461536),
      );
      expect(
        tester.getBottomLeft(find.widgetWithText(Center, '-1')).dy,
        moreOrLessEquals(-115.38461538461536),
      );
      expect(
        tester.getTopLeft(find.widgetWithText(Center, '0')).dy,
        moreOrLessEquals(-115.38461538461536),
      );

      // Scroll the top of the refresh indicator back to overscroll, it will
      // snap to the size of the refresh indicator and stay there.
      await tester.drag(find.text('1'), const Offset(0.0, 200.0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.getRect(find.widgetWithText(Center, '-1')),
        new Rect.fromLTRB(0.0, 0.0, 800.0, 65.0),
      );
      expect(
        tester.getRect(find.widgetWithText(Center, '0')),
        new Rect.fromLTRB(0.0, 65.0, 800.0, 265.0),
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('expanded refreshing sliver goes away when done', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      refreshIndicator = const Center(child: const Text('-1'));

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
                onRefresh: mockHelper.refreshTask,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      await tester.drag(find.text('0'), const Offset(0.0, 150.0));
      await tester.pump();
      verify(mockHelper.builder(
        any,
        RefreshIndicatorMode.armed,
        150.0,
        100.0, // Default value.
        65.0, // Default value.
      ));
      expect(
        tester.getRect(find.widgetWithText(Center, '-1')),
        new Rect.fromLTRB(0.0, 0.0, 800.0, 150.0),
      );
      verify(mockHelper.refreshTask());

      // Rebuilds the sliver with a layout extent now.
      await tester.pump();
      // Let it snap back to occupy the indicator's final sliver space only.
      await tester.pump(const Duration(seconds: 2));
      verify(mockHelper.builder(
        any,
        RefreshIndicatorMode.refresh,
        65.0,
        100.0, // Default value.
        65.0, // Default value.
      ));
      expect(
        tester.getRect(find.widgetWithText(Center, '-1')),
        new Rect.fromLTRB(0.0, 0.0, 800.0, 65.0),
      );
      expect(
        tester.getRect(find.widgetWithText(Center, '0')),
        new Rect.fromLTRB(0.0, 65.0, 800.0, 265.0),
      );

      refreshCompleter.complete(null);
      await tester.pump();
      verify(mockHelper.builder(
        any,
        RefreshIndicatorMode.done,
        65.0,
        100.0, // Default value.
        65.0, // Default value.
      ));

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('-1'), findsNothing);
      expect(
        tester.getRect(find.widgetWithText(Center, '0')),
        new Rect.fromLTRB(0.0, 0.0, 800.0, 200.0),
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'retracting sliver during done cannot be pulled to refresh again until fully retracted',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        refreshIndicator = const Center(child: const Text('-1'));

        await tester.pumpWidget(
          new Directionality(
            textDirection: TextDirection.ltr,
            child: new CustomScrollView(
              slivers: <Widget>[
                new CupertinoRefreshControl(
                  builder: mockHelper.builder,
                  onRefresh: mockHelper.refreshTask,
                ),
                buildAListOfStuff(),
              ],
            ),
          ),
        );

        await tester.drag(find.text('0'), const Offset(0.0, 150.0));
        await tester.pump();
        verify(mockHelper.refreshTask());

        refreshCompleter.complete(null);
        await tester.pump();
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.done,
          150.0, // Still overscrolled here.
          100.0, // Default value.
          65.0, // Default value.
        ));

        // Let it start going away but not fully.
        await tester.pump(const Duration(milliseconds: 100));
        // The refresh indicator is still building.
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.done,
          91.31180913199277,
          100.0, // Default value.
          65.0, // Default value.
        ));
        expect(
          tester.getBottomLeft(find.widgetWithText(Center, '-1')).dy,
          moreOrLessEquals(91.311809131992776),
        );

        // Start another drag by an amount that would have been enough to
        // trigger another refresh if it were in the right state.
        await tester.drag(find.text('0'), const Offset(0.0, 150.0));
        await tester.pump();

        // Instead, it's still in the done state because the sliver never
        // fully retracted.
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.done,
          147.3772721631821,
          100.0, // Default value.
          65.0, // Default value.
        ));

        // Now let it fully go away.
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('-1'), findsNothing);
        expect(
          tester.getRect(find.widgetWithText(Center, '0')),
          new Rect.fromLTRB(0.0, 0.0, 800.0, 200.0),
        );

        // Start another drag. It's now in drag mode.
        await tester.drag(find.text('0'), const Offset(0.0, 40.0));
        await tester.pump();
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          40.0,
          100.0, // Default value.
          65.0, // Default value.
        ));

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'sliver held in overscroll when task finishes completes normally',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        refreshIndicator = const Center(child: const Text('-1'));

        await tester.pumpWidget(
          new Directionality(
            textDirection: TextDirection.ltr,
            child: new CustomScrollView(
              slivers: <Widget>[
                new CupertinoRefreshControl(
                  builder: mockHelper.builder,
                  onRefresh: mockHelper.refreshTask,
                ),
                buildAListOfStuff(),
              ],
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(const Offset(0.0, 0.0));
        // Start a refresh.
        await gesture.moveBy(const Offset(0.0, 150.0));
        await tester.pump();
        verify(mockHelper.refreshTask());

        // Complete the task while held down.
        refreshCompleter.complete(null);
        await tester.pump();
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.done,
          150.0, // Still overscrolled here.
          100.0, // Default value.
          65.0, // Default value.
        ));
        expect(
          tester.getRect(find.widgetWithText(Center, '0')),
          new Rect.fromLTRB(0.0, 150.0, 800.0, 350.0),
        );

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('-1'), findsNothing);
        expect(
          tester.getRect(find.widgetWithText(Center, '0')),
          new Rect.fromLTRB(0.0, 0.0, 800.0, 200.0),
        );

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'sliver scrolled await when task completes properly removes itself',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        refreshIndicator = const Center(child: const Text('-1'));

        await tester.pumpWidget(
          new Directionality(
            textDirection: TextDirection.ltr,
            child: new CustomScrollView(
              slivers: <Widget>[
                new CupertinoRefreshControl(
                  builder: mockHelper.builder,
                  onRefresh: mockHelper.refreshTask,
                ),
                buildAListOfStuff(),
              ],
            ),
          ),
        );

        // Start a refresh.
        await tester.drag(find.text('0'), const Offset(0.0, 150.0));
        await tester.pump();
        verify(mockHelper.refreshTask());

        await tester.drag(find.text('0'), const Offset(0.0, -300.0));
        await tester.pump();

        // Refresh indicator still being told to layout the same way.
        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.refresh,
          65.0,
          100.0, // Default value.
          65.0, // Default value.
        ));

        // Now the sliver is scrolled off screen.
        expect(
          tester.getTopLeft(find.widgetWithText(Center, '-1')).dy,
          moreOrLessEquals(-180.38461538461536),
        );
        expect(
          tester.getBottomLeft(find.widgetWithText(Center, '-1')).dy,
          moreOrLessEquals(-115.38461538461536),
        );

        // Complete the task while scrolled await.
        refreshCompleter.complete(null);
        // The sliver is instantly gone since there is no overscroll physics
        // simulation.
        await tester.pump();

        // The next item's position is not disturbed.
        expect(
          tester.getTopLeft(find.widgetWithText(Center, '0')).dy,
          moreOrLessEquals(-115.38461538461536),
        );

        // Scrolling past the first item still results in a new overscroll.
        // The layout extent is gone.
        await tester.drag(find.text('1'), const Offset(0.0, 120.0));
        await tester.pump();

        verify(mockHelper.builder(
          any,
          RefreshIndicatorMode.drag,
          4.615384615384642,
          100.0, // Default value.
          65.0, // Default value.
        ));

        // Snaps away normally.
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('-1'), findsNothing);
        expect(
          tester.getRect(find.widgetWithText(Center, '0')),
          new Rect.fromLTRB(0.0, 0.0, 800.0, 200.0),
        );

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      "don't do anything unless it can be overscrolled at the start of the list",
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        refreshIndicator = const Center(child: const Text('-1'));

        await tester.pumpWidget(
          new Directionality(
            textDirection: TextDirection.ltr,
            child: new CustomScrollView(
              slivers: <Widget>[
                new CupertinoRefreshControl(
                  builder: mockHelper.builder,
                  onRefresh: mockHelper.refreshTask,
                ),
                buildAListOfStuff(),
              ],
            ),
          ),
        );
      },
    );
  });

  // Test the internal state machine directly to make sure the UI aren't just
  // correct by coincidence.
  group('state machine test', () {
    testWidgets('starts in inactive state', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      expect(
        CupertinoRefreshControl.state(tester.element(find.byType(LayoutBuilder))),
        RefreshIndicatorMode.inactive,
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('goes to drag and returns to inactive in a small drag', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        new Directionality(
          textDirection: TextDirection.ltr,
          child: new CustomScrollView(
            slivers: <Widget>[
              new CupertinoRefreshControl(
                builder: mockHelper.builder,
              ),
              buildAListOfStuff(),
            ],
          ),
        ),
      );

      await tester.drag(find.text('0'), const Offset(0.0, 20.0));
      await tester.pump();

      expect(
        CupertinoRefreshControl.state(tester.element(find.byType(LayoutBuilder))),
        RefreshIndicatorMode.drag,
      );

      await tester.pump(const Duration(seconds: 2));

      expect(
        CupertinoRefreshControl.state(tester.element(find.byType(LayoutBuilder))),
        RefreshIndicatorMode.inactive,
      );

      debugDefaultTargetPlatformOverride = null;
    });
  });

}

class MockHelper extends Mock {
  Widget builder(
    BuildContext context,
    RefreshIndicatorMode refreshState,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  );

  Future<void> refreshTask();
}