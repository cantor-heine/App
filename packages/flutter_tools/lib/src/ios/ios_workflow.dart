// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../base/context.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../base/user_messages.dart';
import '../base/version.dart';
import '../doctor.dart';
import '../macos/xcode.dart';
import 'mac.dart';
import 'plist_utils.dart' as plist;

IOSWorkflow get iosWorkflow => context.get<IOSWorkflow>();
IOSValidator get iosValidator => context.get<IOSValidator>();

class IOSWorkflow implements Workflow {
  const IOSWorkflow();

  @override
  bool get appliesToHostPlatform => platform.isMacOS;

  // We need xcode (+simctl) to list simulator devices, and libimobiledevice to list real devices.
  @override
  bool get canListDevices => xcode.isInstalledAndMeetsVersionCheck && xcode.isSimctlInstalled;

  // We need xcode to launch simulator devices, and ideviceinstaller and ios-deploy
  // for real devices.
  @override
  bool get canLaunchDevices => xcode.isInstalledAndMeetsVersionCheck;

  @override
  bool get canListEmulators => false;

  String getPlistValueFromFile(String path, String key) {
    return plist.getValueFromFile(path, key);
  }
}

class IOSValidator extends DoctorValidator {

  const IOSValidator() : super('iOS tools - develop for iOS devices');

  Future<bool> get hasIDeviceInstaller => exitsHappyAsync(<String>['ideviceinstaller', '-h']);

  Future<bool> get hasIosDeploy => exitsHappyAsync(<String>['ios-deploy', '--version']);

  String get iosDeployMinimumVersion => '1.9.4';

  // ios-deploy <= v1.9.3 declares itself as v2.0.0
  List<String> get iosDeployBadVersions => <String>['2.0.0'];

  Future<String> get iosDeployVersionText async => (await runAsync(<String>['ios-deploy', '--version'])).processResult.stdout.replaceAll('\n', '');

  bool get hasHomebrew => os.which('brew') != null;

  Future<String> get macDevMode async => (await runAsync(<String>['DevToolsSecurity', '-status'])).processResult.stdout;

  Future<bool> get _iosDeployIsInstalledAndMeetsVersionCheck async {
    if (!await hasIosDeploy)
      return false;
    try {
      final Version version = Version.parse(await iosDeployVersionText);
      return version >= Version.parse(iosDeployMinimumVersion)
          && !iosDeployBadVersions.map((String v) => Version.parse(v)).contains(version);
    } on FormatException catch (_) {
      return false;
    }
  }

  // Change this value if the number of checks for packages needed for installation changes
  static const int totalChecks = 4;

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];
    ValidationType packageManagerStatus = ValidationType.installed;

    int checksFailed = 0;

    if (!iMobileDevice.isInstalled) {
      checksFailed += 3;
      packageManagerStatus = ValidationType.partial;
      messages.add(ValidationMessage.error(userMessages.iOSIMobileDeviceMissing));
    } else if (!await iMobileDevice.isWorking) {
      checksFailed += 2;
      packageManagerStatus = ValidationType.partial;
      messages.add(ValidationMessage.error(userMessages.iOSIMobileDeviceBroken));
    } else if (!await hasIDeviceInstaller) {
      checksFailed += 1;
      packageManagerStatus = ValidationType.partial;
      messages.add(ValidationMessage.error(userMessages.iOSDeviceInstallerMissing));
    }

    final bool iHasIosDeploy = await hasIosDeploy;

    // Check ios-deploy is installed at meets version requirements.
    if (iHasIosDeploy) {
      messages.add(ValidationMessage(userMessages.iOSDeployVersion(await iosDeployVersionText)));
    }
    if (!await _iosDeployIsInstalledAndMeetsVersionCheck) {
      packageManagerStatus = ValidationType.partial;
      if (iHasIosDeploy) {
        messages.add(ValidationMessage.error(userMessages.iOSDeployOutdated(iosDeployMinimumVersion)));
      } else {
        checksFailed += 1;
        messages.add(ValidationMessage.error(userMessages.iOSDeployMissing));
      }
    }

    // If one of the checks for the packages failed, we may need brew so that we can install
    // the necessary packages. If they're all there, however, we don't even need it.
    if (checksFailed == totalChecks)
      packageManagerStatus = ValidationType.missing;
    if (checksFailed > 0 && !hasHomebrew) {
      messages.add(ValidationMessage.hint(userMessages.iOSBrewMissing));
    }

    return ValidationResult(packageManagerStatus, messages);
  }
}
