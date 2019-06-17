
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  test('$WidgetsBinding initializes with $AutomatedTestWidgetsFlutterBinding when FLUTTER_TEST has a value that is not "true" or "false"', () {
    TestWidgetsFlutterBinding.ensureInitialized({'FLUTTER_TEST': 'value that is neither "true" nor "false"'});
    expect(WidgetsBinding.instance, isInstanceOf<AutomatedTestWidgetsFlutterBinding>());
  });
}