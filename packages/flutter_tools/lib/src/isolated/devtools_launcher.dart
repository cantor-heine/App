// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../base/io.dart' as io;
import '../base/logger.dart';
import '../convert.dart';
import '../resident_runner.dart';

/// An implementation of the devtools launcher that uses the server package.
///
/// This is implemented in isolated to prevent the flutter_tool from needing
/// a devtools dep in google3.
class DevtoolsServerLauncher extends DevtoolsLauncher {
  DevtoolsServerLauncher({
    @required ProcessManager processManager,
    @required String pubExecutable,
    @required Logger logger,
  })  : _processManager = processManager,
        _pubExecutable = pubExecutable,
        _logger = logger;

  final ProcessManager _processManager;
  final String _pubExecutable;
  final Logger _logger;

  io.Process _devToolsProcess;
  Uri _devToolsUri;

  static final RegExp _serveDevToolsPattern =
      RegExp(r'Serving DevTools at ((http|//)[a-zA-Z0-9:/=_\-\.\[\]]+)');

  @override
  Future<void> launch(Uri vmServiceUri) async {
    if (_devToolsProcess != null) {
      // DevTools is already running.
      return;
    }

    try {
      final ProcessResult _devToolsActivateProcess = await _processManager.run(<String>[
        _pubExecutable,
        'global',
        'activate',
        'devtools'
      ]);
      if (_devToolsActivateProcess.exitCode != 0) {
        _logger.printError('Error running `pub global activate '
            'devtools`. Could not activate devtools.');
        return;
      }

      _devToolsProcess = await _processManager.start(<String>[
        _pubExecutable,
        'global',
        'run',
        'devtools',
        if (vmServiceUri != null) '--vm-uri=$vmServiceUri',
      ]);
      final Completer<Uri> completer = Completer<Uri>();
      _devToolsProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
            final Match match = _serveDevToolsPattern.firstMatch(line);
            if (match != null) {
              // We are trying to pull "http://127.0.0.1:9101" from "Serving
              // DevTools at http://127.0.0.1:9101.". `match[1]` will return
              // "http://127.0.0.1:9101.", and we need to trim the trailing period
              // so that we don't throw an exception from `Uri.parse`.
              String uri = match[1];
              if (uri.endsWith('.')) {
                uri = uri.substring(0, uri.length - 1);
              }
              completer.complete(Uri.parse(uri));
            }
            _logger.printStatus(line);
         });
      _devToolsProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_logger.printError);
      _devToolsUri = await completer.future;
    } on Exception catch (e, st) {
      _logger.printError('Failed to launch DevTools: $e', stackTrace: st);
    }
  }

  @override
  Future<DevToolsServerAddress> serve() async {
    await launch(null);
    if (_devToolsUri == null) {
      return null;
    }
    return DevToolsServerAddress(_devToolsUri.host, _devToolsUri.port);
  }

  @override
  Future<void> close() async {
    _devToolsProcess.kill();
    await _devToolsProcess.exitCode;
  }
}
