// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'utils.dart';

class MaskConstant {
  const MaskConstant({required this.name, required this.value, required this.description});

  const MaskConstant.platform({required String platform, required int value})
      : this(
            name: '$platform Plane',
            value: value,
            description: 'The plane value for the private keys defined by the $platform embedding.');

  final String name;
  final int value;
  final String description;

  String get upperCamelName {
    return name.split(' ').map<String>((String word) => lowerCamelToUpperCamel(word.toLowerCase())).join();
  }

  String get lowerCamelName {
    final String upperCamel = upperCamelName;
    return upperCamel.substring(0, 1).toLowerCase() + upperCamel.substring(1);
  }
}

const MaskConstant kValueMask = MaskConstant(
  name: 'Value Mask',
  value: 0x00FFFFFFFF,
  description: 'Mask for the 32-bit value portion of the key code.',
);

const MaskConstant kPlaneMask = MaskConstant(
  name: 'Plane Mask',
  value: 0xFF00000000,
  description: 'Mask for the plane prefix portion of the key code.',
);

const MaskConstant kUnicodePlane = MaskConstant(
  name: 'Unicode Plane',
  value: 0x0000000000,
  description: 'The plane value for keys which have a Unicode representation.',
);

const MaskConstant kUnprintablePlane = MaskConstant(
  name: 'Unprintable Plane',
  value: 0x0100000000,
  description: 'The plane value for keys defined by Chromium and does not have a Unicode representation.',
);

const MaskConstant kFlutterPlane = MaskConstant(
  name: 'Flutter Plane',
  value: 0x0200000000,
  description: 'The plane value for keys defined by Flutter.',
);

const MaskConstant kStartOfPlatformPlanes = MaskConstant(
  name: 'Start Of Platform Planes',
  value: 0x1100000000,
  description: 'The platform plane with the lowest mask value, beyond which the keys are considered autogenerated.',
);

const MaskConstant kAndroidPlane = MaskConstant.platform(
  platform: 'Android',
  value: 0x1100000000,
);

const MaskConstant kFuchsiaPlane = MaskConstant.platform(
  platform: 'Fuchsia',
  value: 0x1200000000,
);

const MaskConstant kIosPlane = MaskConstant.platform(
  platform: 'iOS',
  value: 0x1300000000,
);

const MaskConstant kMacosPlane = MaskConstant.platform(
  platform: 'macOS',
  value: 0x1400000000,
);

const MaskConstant kGtkPlane = MaskConstant.platform(
  platform: 'Gtk',
  value: 0x1500000000,
);

const MaskConstant kWindowsPlane = MaskConstant.platform(
  platform: 'Windows',
  value: 0x1600000000,
);

const MaskConstant kWebPlane = MaskConstant.platform(
  platform: 'Web',
  value: 0x1700000000,
);

const MaskConstant kGlfwPlane = MaskConstant.platform(
  platform: 'GLFW',
  value: 0x1800000000,
);
