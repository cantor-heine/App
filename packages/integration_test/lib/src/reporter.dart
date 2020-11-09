// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart';
// ignore: implementation_imports
import 'package:test_core/src/runner/engine.dart';
// ignore: implementation_imports
import 'package:test_core/src/runner/reporter.dart';

import '../common.dart';
import 'constants.dart';

/// A reporter that plugs into [directRunTests] from `package:test_core`.
class ResultReporter implements Reporter {
  /// When the [_engine] has completed execution of tests, [_resultsCompleter]
  /// will be completed with the test results.
  ResultReporter(this._engine, this._resultsCompleter) {
    _subscriptions.add(_engine.success.asStream().listen(_onDone));
  }
  final Engine _engine;
  final Completer<Map<String, Object>> _resultsCompleter;

  final Set<StreamSubscription<Object>> _subscriptions = <StreamSubscription<Object>>{};

  void _onDone(bool _) {
    _cancel();
    final Map<String, Object> results = <String, Object>{
      for (final LiveTest liveTest in _engine.liveTests)
        liveTest.test.name: liveTest.state.result.name == success
            ? success
            : Failure(
                liveTest.test.name, liveTest.errors.first.stackTrace.toString(),
                error: liveTest.errors.first.error)
    };
    _resultsCompleter.complete(results);
  }

  void _cancel() {
    for (final StreamSubscription<Object> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void pause() {}
  @override
  void resume() {}
}
