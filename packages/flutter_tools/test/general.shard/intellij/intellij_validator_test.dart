// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:archive/archive.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/doctor_validator.dart';
import 'package:flutter_tools/src/intellij/intellij_validator.dart';
import 'package:flutter_tools/src/ios/plist_parser.dart';
import 'package:test/fake.dart';

import '../../src/common.dart';
import '../../src/fake_process_manager.dart';

final Platform macPlatform = FakePlatform(
  operatingSystem: 'macos',
  environment: <String, String>{'HOME': '/foo/bar'}
);
final Platform linuxPlatform = FakePlatform(
  operatingSystem: 'linux',
  environment: <String, String>{
    'HOME': '/foo/bar'
  },
);
final Platform windowsPlatform = FakePlatform(
  operatingSystem: 'windows',
  environment: <String, String>{
    'USERPROFILE': r'C:\Users\foo',
    'APPDATA': r'C:\Users\foo\AppData\Roaming',
    'LOCALAPPDATA': r'C:\Users\foo\AppData\Local'
  },
);

void main() {
  testWithoutContext('Intellij validator can parse plugin manifest from plugin JAR', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    // Create plugin JAR file for Flutter and Dart plugin.
    createIntellijFlutterPluginJar('plugins/flutter-intellij.jar', fileSystem);
    createIntellijDartPluginJar('plugins/Dart/lib/Dart.jar', fileSystem);

    final ValidationResult result = await IntelliJValidatorTestTarget('', 'path/to/intellij', fileSystem).validate();
    expect(result.type, ValidationType.partial);
    expect(result.statusInfo, 'version test.test.test');
    expect(result.messages, const <ValidationMessage>[
      ValidationMessage('IntelliJ at path/to/intellij'),
      ValidationMessage.error('Flutter plugin version 0.1.3 - the recommended minimum version is 16.0.0'),
      ValidationMessage('Dart plugin version 162.2485'),
      ValidationMessage('For information about installing plugins, see\n'
          'https://flutter.dev/intellij-setup/#installing-the-plugins')
    ]);
  });

  testWithoutContext('legacy intellij(<2020) plugins check on linux', () async {
    const String cachePath  = '/foo/bar/.IntelliJIdea2019.10/system';
    const String installPath = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-1/2019.10.1';
    const String pluginPath  = '/foo/bar/.IntelliJIdea2019.10/config/plugins';
    final FileSystem fileSystem = MemoryFileSystem.test();

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    // Create plugin JAR file for Flutter and Dart plugin.
    createIntellijFlutterPluginJar('$pluginPath/flutter-intellij/lib/flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar('$pluginPath/Dart/lib/Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnLinux.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: linuxPlatform),
      userMessages: UserMessages(),
      );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('intellij(2020.1) plugins check on linux (installed via JetBrains ToolBox app)', () async {
    const String cachePath   = '/foo/bar/.cache/JetBrains/IntelliJIdea2020.10';
    const String installPath = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-1/2020.10.1';
    const String pluginPath  = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-1/2020.10.1.plugins';
    final FileSystem fileSystem = MemoryFileSystem.test();

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    // Create plugin JAR file for Flutter and Dart plugin.
    createIntellijFlutterPluginJar('$pluginPath/flutter-intellij/lib/flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar('$pluginPath/Dart/lib/Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnLinux.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: linuxPlatform),
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('intellij(>=2020.2) plugins check on linux (installed via JetBrains ToolBox app)', () async {
    const String cachePath   = '/foo/bar/.cache/JetBrains/IntelliJIdea2020.10';
    const String installPath = '/foo/bar/.local/share/JetBrains/Toolbox/apps/IDEA-U/ch-1/2020.10.1';
    const String pluginPath  = '/foo/bar/.local/share/JetBrains/IntelliJIdea2020.10';
    final FileSystem fileSystem = MemoryFileSystem.test();

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    // Create plugin JAR file for Flutter and Dart plugin.
    createIntellijFlutterPluginJar('$pluginPath/flutter-intellij/lib/flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar('$pluginPath/Dart/lib/Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnLinux.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: linuxPlatform),
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('intellij(2020.1~) plugins check on linux (installed via tar.gz)', () async {
    const String cachePath   = '/foo/bar/.cache/JetBrains/IdeaIC2020.10';
    const String installPath = '/foo/bar/some/dir/ideaIC-2020.10.1/idea-IC-201.0000.00';
    const String pluginPath  = '/foo/bar/.local/share/JetBrains/IdeaIC2020.10';
    final FileSystem fileSystem = MemoryFileSystem.test();

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    // Create plugin JAR file for Flutter and Dart plugin.
    createIntellijFlutterPluginJar('$pluginPath/flutter-intellij/lib/flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar('$pluginPath/Dart/lib/Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnLinux.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: linuxPlatform),
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('legacy intellij(<2020) plugins check on windows', () async {
    const String cachePath   = r'C:\Users\foo\.IntelliJIdea2019.10\system';
    const String installPath = r'C:\Program Files\JetBrains\IntelliJ IDEA Ultimate Edition 2019.10.1';
    const String pluginPath  = r'C:\Users\foo\.IntelliJIdea2019.10\config\plugins';
    final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.windows);

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    createIntellijFlutterPluginJar('$pluginPath/flutter-intellij/lib/flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar('$pluginPath/Dart/lib/Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnWindows.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: windowsPlatform),
      platform: windowsPlatform,
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('intellij(2020.1 ~ 2020.2) plugins check on windows (installed via JetBrains ToolBox app)', () async {
    const String cachePath   = r'C:\Users\foo\AppData\Local\JetBrains\IntelliJIdea2020.10';
    const String installPath = r'C:\Users\foo\AppData\Local\JetBrains\Toolbox\apps\IDEA-U\ch-0\201.0000.00';
    const String pluginPath  = r'C:\Users\foo\AppData\Roaming\JetBrains\IntelliJIdea2020.10\plugins';
    final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.windows);

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    createIntellijFlutterPluginJar(pluginPath + r'\flutter-intellij\lib\flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar(pluginPath + r'\Dart\lib\Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnWindows.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: windowsPlatform),
      platform: windowsPlatform,
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('intellij(>=2020.3) plugins check on windows (installed via JetBrains ToolBox app and plugins)', () async {
    const String cachePath   = r'C:\Users\foo\AppData\Local\JetBrains\IntelliJIdea2020.10';
    const String installPath = r'C:\Users\foo\AppData\Local\JetBrains\Toolbox\apps\IDEA-U\ch-0\201.0000.00';
    const String pluginPath  = r'C:\Users\foo\AppData\Local\JetBrains\Toolbox\apps\IDEA-U\ch-0\201.0000.00.plugins';
    final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.windows);

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    createIntellijFlutterPluginJar(pluginPath + r'\flutter-intellij\lib\flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar(pluginPath + r'\Dart\lib\Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnWindows.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: windowsPlatform),
      platform: windowsPlatform,
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('intellij(2020.1~) plugins check on windows (installed via installer)', () async {
    const String cachePath   = r'C:\Users\foo\AppData\Local\JetBrains\IdeaIC2020.10';
    const String installPath = r'C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2020.10.1';
    const String pluginPath  = r'C:\Users\foo\AppData\Roaming\JetBrains\IdeaIC2020.10\plugins';
    final FileSystem fileSystem = MemoryFileSystem.test(style: FileSystemStyle.windows);

    final Directory cacheDirectory = fileSystem.directory(cachePath)
      ..createSync(recursive: true);
    cacheDirectory
        .childFile('.home')
        .writeAsStringSync(installPath, flush: true);
    final Directory installedDirectory = fileSystem.directory(installPath);
    installedDirectory.createSync(recursive: true);
    createIntellijFlutterPluginJar(pluginPath + r'\flutter-intellij\lib\flutter-intellij.jar', fileSystem, version: '50.0');
    createIntellijDartPluginJar(pluginPath + r'\Dart\lib\Dart.jar', fileSystem);

    final Iterable<DoctorValidator> installed = IntelliJValidatorOnWindows.installed(
      fileSystem: fileSystem,
      fileSystemUtils: FileSystemUtils(fileSystem: fileSystem, platform: windowsPlatform),
      platform: windowsPlatform,
      userMessages: UserMessages(),
    );
    expect(1, installed.length);
    final ValidationResult result = await installed.toList()[0].validate();
    expect(ValidationType.installed, result.type);
  });

  testWithoutContext('can locate installations on macOS from Spotlight', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final String ceRandomLocation = fileSystem.path.join(
      '/',
      'random',
      'IntelliJ CE (stable).app',
    );
    final String ultimateRandomLocation = fileSystem.path.join(
      '/',
      'random',
      'IntelliJ UE (stable).app',
    );

    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      FakeCommand(
        command: const <String>[
          'mdfind',
          'kMDItemCFBundleIdentifier="com.jetbrains.intellij.ce"',
        ],
        stdout: ceRandomLocation,
      ),
      FakeCommand(
        command: const <String>[
          'mdfind',
          'kMDItemCFBundleIdentifier="com.jetbrains.intellij*"',
        ],
        stdout: '$ultimateRandomLocation\n$ceRandomLocation',
      ),
    ]);
    final Iterable<IntelliJValidatorOnMac> validators = IntelliJValidator.installedValidators(
      fileSystem: fileSystem,
      platform: macPlatform,
      userMessages: UserMessages(),
      processManager: processManager,
      plistParser: FakePlistParser(<String, String>{
        PlistParser.kCFBundleShortVersionStringKey: '2020.10',
      }),
    ).whereType<IntelliJValidatorOnMac>();
    expect(validators.length, 2);

    final IntelliJValidatorOnMac ce = validators.where((IntelliJValidatorOnMac validator) => validator.id == 'IdeaIC').single;
    expect(ce.title, 'IntelliJ IDEA Community Edition');
    expect(ce.installPath, ceRandomLocation);

    final IntelliJValidatorOnMac ultimate = validators.where((IntelliJValidatorOnMac validator) => validator.id == 'IntelliJIdea').single;
    expect(ultimate.title, 'IntelliJ IDEA Ultimate Edition');
    expect(ultimate.installPath, ultimateRandomLocation);
  });

  testWithoutContext('Intellij plugins path checking on mac', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final Directory pluginsDirectory = fileSystem.directory('/foo/bar/Library/Application Support/JetBrains/TestID2020.10/plugins')
      ..createSync(recursive: true);
    final IntelliJValidatorOnMac validator = IntelliJValidatorOnMac(
      'Test',
      'TestID',
      '/path/to/app',
      fileSystem: fileSystem,
      homeDirPath: '/foo/bar',
      userMessages: UserMessages(),
      plistParser: FakePlistParser(<String, String>{
        PlistParser.kCFBundleShortVersionStringKey: '2020.10',
      })
    );

    expect(validator.plistFile, '/path/to/app/Contents/Info.plist');
    expect(validator.pluginsPath, pluginsDirectory.path);
  });

  testWithoutContext('legacy Intellij plugins path checking on mac', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final IntelliJValidatorOnMac validator = IntelliJValidatorOnMac(
      'Test',
      'TestID',
      '/foo',
      fileSystem: fileSystem,
      homeDirPath: '/foo/bar',
      userMessages: UserMessages(),
      plistParser: FakePlistParser(<String, String>{
        PlistParser.kCFBundleShortVersionStringKey: '2020.10',
      })
    );

    expect(validator.pluginsPath, '/foo/bar/Library/Application Support/TestID2020.10');
  });

  testWithoutContext('Intellij plugins path checking on mac with JetBrains toolbox override', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final IntelliJValidatorOnMac validator = IntelliJValidatorOnMac(
      'Test',
      'TestID',
      '/foo',
      fileSystem: fileSystem,
      homeDirPath: '/foo/bar',
      userMessages: UserMessages(),
      plistParser: FakePlistParser(<String, String>{
        'JetBrainsToolboxApp': '/path/to/JetBrainsToolboxApp',
      })
    );

    expect(validator.pluginsPath, '/path/to/JetBrainsToolboxApp.plugins');
  });
}

class FakePlistParser extends Fake implements PlistParser {
  FakePlistParser(this.values);

  final Map<String, String> values;

  @override
  String? getValueFromFile(String plistFilePath, String key) {
    return values[key];
  }
}

class IntelliJValidatorTestTarget extends IntelliJValidator {
  IntelliJValidatorTestTarget(String title, String installPath,  FileSystem fileSystem)
    : super(title, installPath, fileSystem: fileSystem, userMessages: UserMessages());

  @override
  String get pluginsPath => 'plugins';

  @override
  String get version => 'test.test.test';
}

/// A helper to create a Intellij Flutter plugin jar.
///
/// These file contents were derived from the META-INF/plugin.xml from an Intellij Flutter
/// plugin installation.
///
/// The file is located in a plugin JAR, which can be located by looking at the plugin
/// path for the Intellij and Android Studio validators.
///
/// If more XML contents are needed, prefer modifying these contents over checking
/// in another JAR.
void createIntellijFlutterPluginJar(String pluginJarPath, FileSystem fileSystem, {String version = '0.1.3'}) {
  final String intellijFlutterPluginXml = '''
<idea-plugin version="2">
  <id>io.flutter</id>
  <name>Flutter</name>
  <description>Support for developing Flutter applications.</description>
  <vendor url="https://github.com/flutter/flutter-intellij">flutter.io</vendor>

  <category>Custom Languages</category>

  <version>$version</version>

  <idea-version since-build="162.1" until-build="163.*"/>
</idea-plugin>
''';

  final List<int> flutterPluginBytes = utf8.encode(intellijFlutterPluginXml);
  final Archive flutterPlugins = Archive();
  flutterPlugins.addFile(ArchiveFile('META-INF/plugin.xml', flutterPluginBytes.length, flutterPluginBytes));
  fileSystem.file(pluginJarPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(ZipEncoder().encode(flutterPlugins)!);

}

/// A helper to create a Intellij Dart plugin jar.
///
/// This jar contains META-INF/plugin.xml.
/// Its contents were derived from the META-INF/plugin.xml from an Intellij Dart
/// plugin installation.
///
/// The file is located in a plugin JAR, which can be located by looking at the plugin
/// path for the Intellij and Android Studio validators.
///
/// If more XML contents are needed, prefer modifying these contents over checking
/// in another JAR.
void createIntellijDartPluginJar(String pluginJarPath, FileSystem fileSystem) {
  const String intellijDartPluginXml = r'''
<idea-plugin version="2">
  <name>Dart</name>
  <version>162.2485</version>
  <idea-version since-build="162.1121" until-build="162.*"/>

  <description>Support for Dart programming language</description>
  <vendor>JetBrains</vendor>
  <depends>com.intellij.modules.xml</depends>
  <depends optional="true" config-file="dartium-debugger-support.xml">JavaScriptDebugger</depends>
  <depends optional="true" config-file="dart-yaml.xml">org.jetbrains.plugins.yaml</depends>
  <depends optional="true" config-file="dart-copyright.xml">com.intellij.copyright</depends>
  <depends optional="true" config-file="dart-coverage.xml">com.intellij.modules.coverage</depends>
</idea-plugin>
''';

  final List<int> dartPluginBytes = utf8.encode(intellijDartPluginXml);
  final Archive dartPlugins = Archive();
  dartPlugins.addFile(ArchiveFile('META-INF/plugin.xml', dartPluginBytes.length, dartPluginBytes));
  fileSystem.file(pluginJarPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(ZipEncoder().encode(dartPlugins)!);
}
