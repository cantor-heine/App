// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recorder.dart';

class _NestedMouseRegion extends StatelessWidget {
  const _NestedMouseRegion({this.nests, this.child});

  final int nests;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget current = child;
    for (int i = 0; i < nests; i++) {
      current = MouseRegion(
        onEnter: (_) {},
        child: child,
      );
    }
    return current;
  }
}

/// Creates a grid of mouse regions, then continuously hover over them.
///
/// Measures our ability to hit test mouse regions.
class BenchMouseRegionGridHover extends WidgetRecorder {
  BenchMouseRegionGridHover() : super(name: benchmarkName);

  static const String benchmarkName = 'bench_mouse_region_grid_hover';

  final _Tester tester = _Tester();

  // Use a non-trivial border to force Web to switch painter
  Border _getBorder(int columnIndex, int rowIndex) {
    const BorderSide defaultBorderSide = BorderSide();

    return Border(
      left: columnIndex == 0 ? defaultBorderSide : BorderSide.none,
      top: rowIndex == 0 ? defaultBorderSide : BorderSide.none,
      right: defaultBorderSide,
      bottom: defaultBorderSide,
    );
  }

  bool started = false;

  @override
  void frameDidDraw() {
    if (!started) {
      started = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) async {
        tester.start();
      });
    }
    super.frameDidDraw();
  }

  @override
  Widget createWidget() {
    const int rowsCount = 60;
    const int columnsCount = 20;
    const double containerSize = 20;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 400,
          child: ListView.builder(
            itemCount: rowsCount,
            cacheExtent: rowsCount * containerSize,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (BuildContext context, int rowIndex) => _NestedMouseRegion(
              nests: 10,
              child: Row(
                children: List<Widget>.generate(
                  columnsCount,
                  (int columnIndex) => _NestedMouseRegion(
                    nests: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        border: _getBorder(columnIndex, rowIndex),
                        color: Color.fromARGB(255, rowIndex * 20 % 256, 127, 127),
                      ),
                      width: containerSize,
                      height: containerSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tester {
  static const Duration hoverDuration = Duration(milliseconds: 20);

  bool _stopped = false;

  TestGesture get gesture {
    return _gesture ??= TestGesture(
      dispatcher: (PointerEvent event, HitTestResult result) async {
        RendererBinding.instance.dispatchEvent(event, result);
      },
      hitTester: (Offset location) {
        final HitTestResult result = HitTestResult();
        RendererBinding.instance.hitTest(result, location);
        return result;
      },
      kind: PointerDeviceKind.mouse,
    );
  }
  TestGesture _gesture;

  Duration currentTime = Duration.zero;

  Future<void> _hoverTo(Offset location, Duration duration) async {
    currentTime += duration;
    await gesture.moveTo(location, timeStamp: currentTime);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> start() async {
    await Future<void>.delayed(Duration.zero);
    while (!_stopped) {
      await _hoverTo(const Offset(30, 10), hoverDuration);
      await _hoverTo(const Offset(10, 370), hoverDuration);
      await _hoverTo(const Offset(370, 390), hoverDuration);
      await _hoverTo(const Offset(390, 30), hoverDuration);
    }
  }

  void stop() {
    _stopped = true;
  }
}
