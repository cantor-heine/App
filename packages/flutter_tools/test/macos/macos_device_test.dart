// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/macos/macos_device.dart';

import '../src/common.dart';

void main() {
  group(MacOSDevice, () {
    test('unimplemented methods', () {
      final MacOSDevice device = MacOSDevice();
      expect(() => device.installApp(null), throwsA(isInstanceOf<UnimplementedError>()));
      expect(() => device.uninstallApp(null), throwsA(isInstanceOf<UnimplementedError>()));
      expect(() => device.isLatestBuildInstalled(null), throwsA(isInstanceOf<UnimplementedError>()));
      expect(() => device.startApp(null), throwsA(isInstanceOf<UnimplementedError>()));
      expect(() => device.stopApp(null), throwsA(isInstanceOf<UnimplementedError>()));
      expect(() => device.isAppInstalled(null), throwsA(isInstanceOf<UnimplementedError>()));
    });

    test('noop port forwarding', () async {
      final MacOSDevice device = MacOSDevice();
      final DevicePortForwarder portForwarder = device.portForwarder;
      final int result = await portForwarder.forward(2);
      expect(result, 2);
      expect(portForwarder.forwardedPorts.isEmpty, true);
      expect(() => portForwarder.forward(1, hostPort: 23), throwsA(isInstanceOf<UnimplementedError>()));
    });
  });
}
