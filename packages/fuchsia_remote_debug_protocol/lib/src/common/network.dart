// Copyright 2018 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

/// Determines whether the address is valid IPv6 or IPv4 format.
///
/// Throws an `ArgumentError` if the address is neither.
void validateAddress(String address) {
  if (!(isIpV4Address(address) || isIpV6Address(address))) {
    throw new ArgumentError('"$address" is neither valid IPv4 nor IPv6');
  }
}

/// Returns true if the address is a valid IPv6 address.
bool isIpV6Address(String address) {
  try {
    Uri.parseIPv6Address(address);
    return true;
  } on FormatException catch (e) {
    return false;
  }
}

/// Returns true if the address is a valid IPv4 address.
bool isIpV4Address(String address) {
  try {
    Uri.parseIPv4Address(address);
    return true;
  } on FormatException catch (e) {
    return false;
  }
}
