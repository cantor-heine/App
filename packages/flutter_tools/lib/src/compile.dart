// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:usage/uuid/uuid.dart';

import 'artifacts.dart';
import 'base/file_system.dart';
import 'base/io.dart';
import 'globals.dart';

String _dartExecutable() {
  final String engineDartSdkPath = artifacts.getArtifactPath(
    Artifact.engineDartSdkPath
  );
  return fs.path.join(engineDartSdkPath, 'bin', 'dart');
}

class _StdoutHandler {
  String boundaryKey;
  Completer<String> outputFilename = new Completer<String>();

  void handler(String string) {
    const String kResultPrefix = 'result ';
    if (boundaryKey == null) {
      if (string.startsWith(kResultPrefix))
        boundaryKey = string.substring(kResultPrefix.length);
    } else if (string.startsWith(boundaryKey))
      outputFilename.complete(string.length > boundaryKey.length
        ? string.substring(boundaryKey.length + 1)
        : null);
    else
      printTrace('compile debug message: $string');
  }
}

Future<String> compile({String sdkRoot, String mainPath}) async {
  final String frontendServer = artifacts.getArtifactPath(
    Artifact.frontendServerSnapshotForEngineDartSdk
  );

  // This is a URI, not a file path, so the forward slash is correct even on Windows.
  if (!sdkRoot.endsWith('/'))
    sdkRoot = '$sdkRoot/';
  final Process server = await Process.start(_dartExecutable(),
    <String>[frontendServer, '--sdk-root', sdkRoot, mainPath]
  );

  final _StdoutHandler stdoutHandler = new _StdoutHandler();
  server.stderr
    .transform(UTF8.decoder)
    .listen(printTrace);
  server.stdout
    .transform(UTF8.decoder)
    .transform(new LineSplitter())
    .listen(stdoutHandler.handler);
  await server.exitCode;
  return stdoutHandler.outputFilename.future;
}

/// Wrapper around incremental frontend server compiler, that communicates with
/// server via stdin/stdout.
///
/// The wrapper is intended to stay resident in memory as user changes, reloads,
/// restarts the Flutter app.
class ResidentCompiler {
  ResidentCompiler(this._sdkRoot) {
    assert(_sdkRoot != null);
    // This is a URI, not a file path, so the forward slash is correct even on Windows.
    if (!_sdkRoot.endsWith('/'))
      _sdkRoot = '$_sdkRoot/';
  }

  String _sdkRoot;
  Process _server;
  final _StdoutHandler stdoutHandler = new _StdoutHandler();

  Future<String> recompile(String mainPath, List<String> invalidatedFiles) async {
    // First time recompile is called we actually have to compile the app from
    // scratch ignoring list of invalidated files.
    if (_server == null)
      return _compile(mainPath);

    final String inputKey = new Uuid().generateV4();
    _server.stdin.writeln('recompile $inputKey');
    for (String invalidatedFile in invalidatedFiles)
      _server.stdin.writeln(invalidatedFile);
    _server.stdin.writeln(inputKey);

    return stdoutHandler.outputFilename.future;
  }

  Future<String> _compile(String scriptFilename) async {
    if (_server == null) {
      final String frontendServer = artifacts.getArtifactPath(
        Artifact.frontendServerSnapshotForEngineDartSdk
      );
      _server = await Process.start(_dartExecutable(),
        <String>[frontendServer, '--sdk-root', _sdkRoot, '--incremental']
      );
    }
    _server.stdout
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen(stdoutHandler.handler);
    _server.stderr
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen((String s) { printTrace('stderr:>$s'); });

    _server.stdin.writeln('compile $scriptFilename');

    return stdoutHandler.outputFilename.future;
  }

  void accept() {
    _server.stdin.writeln('accept');
  }

  void reject() {
    _server.stdin.writeln('reject');
  }
}
