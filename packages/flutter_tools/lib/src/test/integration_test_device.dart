// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../application_package.dart';
import '../build_info.dart';
import '../device.dart';
import '../globals.dart' as globals;
import '../vmservice.dart';
import 'test_device.dart';

const String kIntegrationTestExtension = 'Flutter.IntegrationTest';
const String kIntegrationTestData = 'data';
const String kIntegrationTestMethod = 'ext.flutter.integrationTest';

class IntegrationTestTestDevice implements TestDevice {
  IntegrationTestTestDevice({
    required this.id,
    required this.device,
    required this.debuggingOptions,
    required this.userIdentifier,
    required this.compileExpression,
  });

  final int id;
  final Device device;
  final DebuggingOptions debuggingOptions;
  final String? userIdentifier;
  final CompileExpression? compileExpression;

  ApplicationPackage? _applicationPackage;
  final Completer<void> _finished = Completer<void>();
  final Completer<Uri> _gotProcessObservatoryUri = Completer<Uri>();

  /// Starts the device.
  ///
  /// [entrypointPath] must be a path to an un-compiled source file.
  @override
  Future<StreamChannel<String>> start(String entrypointPath) async {
    final TargetPlatform targetPlatform = await device.targetPlatform;
    _applicationPackage = await ApplicationPackageFactory.instance?.getPackageForPlatform(
      targetPlatform,
      buildInfo: debuggingOptions.buildInfo,
    );
    if (_applicationPackage == null) {
      throw TestDeviceException('No application found for $targetPlatform.', StackTrace.current);
    }

    final LaunchResult launchResult = await device.startApp(
      _applicationPackage,
      mainPath: entrypointPath,
      platformArgs: <String, dynamic>{},
      debuggingOptions: debuggingOptions,
      userIdentifier: userIdentifier,
    );
    if (!launchResult.started) {
      throw TestDeviceException('Unable to start the app on the device.', StackTrace.current);
    }
    final Uri? observatoryUri = launchResult.observatoryUri;
    if (observatoryUri == null) {
      throw TestDeviceException('Observatory is not available on the test device.', StackTrace.current);
    }

    // No need to set up the log reader because the logs are captured and
    // streamed to the package:test_core runner.

    _gotProcessObservatoryUri.complete(observatoryUri);

    globals.printTrace('test $id: Connecting to vm service');
    final FlutterVmService vmService = await connectToVmService(
      observatoryUri,
      logger: globals.logger,
      compileExpression: compileExpression,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Connecting to the VM Service timed out.'),
    );

    globals.printTrace('test $id: Finding the correct isolate with the integration test service extension');
    final vm_service.IsolateRef isolateRef = await vmService.findExtensionIsolate(
      kIntegrationTestMethod,
    );

    await vmService.service.streamListen(vm_service.EventStreams.kExtension);
    final Stream<String> remoteMessages = vmService.service.onExtensionEvent
        .where((vm_service.Event e) => e.extensionKind == kIntegrationTestExtension)
        .map((vm_service.Event e) => e.extensionData!.data[kIntegrationTestData] as String);

    final StreamChannelController<String> controller = StreamChannelController<String>();

    controller.local.stream.listen((String event) {
      vmService.service.callServiceExtension(
        kIntegrationTestMethod,
        isolateId: isolateRef.id,
        args: <String, String>{
          kIntegrationTestData: event,
        },
      );
    });

    remoteMessages.listen(
      (String s) => controller.local.sink.add(s),
      onError: (Object error, StackTrace stack) => controller.local.sink.addError(error, stack),
    );
    unawaited(vmService.service.onDone.whenComplete(
      () => controller.local.sink.close(),
    ));

    return controller.foreign;
  }

  @override
  Future<Uri> get observatoryUri => _gotProcessObservatoryUri.future;

  @override
  Future<void> kill() async {
    final ApplicationPackage? applicationPackage = _applicationPackage;
    if (applicationPackage != null) {
      if (!await device.stopApp(applicationPackage, userIdentifier: userIdentifier)) {
        globals.printTrace('Could not stop the Integration Test app.');
      }
      if (!await device.uninstallApp(applicationPackage, userIdentifier: userIdentifier)) {
        globals.printTrace('Could not uninstall the Integration Test app.');
      }
    }

    await device.dispose();
    _finished.complete();
  }

  @override
  Future<void> get finished => _finished.future;
}
