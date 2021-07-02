// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:args/command_runner.dart';
import 'package:conductor/next.dart';
import 'package:conductor/proto/conductor_state.pb.dart' as pb;
import 'package:conductor/proto/conductor_state.pbenum.dart' show ReleasePhase;
import 'package:conductor/repository.dart';
import 'package:conductor/state.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

import './common.dart';
import '../../../packages/flutter_tools/test/src/fake_process_manager.dart';

void main() {
  group('next command', () {
    const String flutterRoot = '/flutter';
    const String checkoutsParentDirectory = '$flutterRoot/dev/tools/';
    const String candidateBranch = 'flutter-1.2-candidate.3';
    final String localPathSeparator = const LocalPlatform().pathSeparator;
    final String localOperatingSystem = const LocalPlatform().pathSeparator;
    const String revision1 = 'abc123';
    MemoryFileSystem fileSystem;
    TestStdio stdio;
    const String stateFile = '/state-file.json';

    setUp(() {
      stdio = TestStdio();
      fileSystem = MemoryFileSystem.test();
    });

    CommandRunner<void> createRunner({
      @required Checkouts checkouts,
    }) {
      final NextCommand command = NextCommand(
        checkouts: checkouts,
      );
      return CommandRunner<void>('codesign-test', '')..addCommand(command);
    }

    test('throws if no state file found', () async {
      final FakeProcessManager processManager = FakeProcessManager.list(
        <FakeCommand>[],
      );
      final FakePlatform platform = FakePlatform(
        environment: <String, String>{
          'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
        },
        operatingSystem: localOperatingSystem,
        pathSeparator: localPathSeparator,
      );
      final Checkouts checkouts = Checkouts(
        fileSystem: fileSystem,
        parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
        platform: platform,
        processManager: processManager,
        stdio: stdio,
      );
      final CommandRunner<void> runner = createRunner(checkouts: checkouts);
      expect(
        () async => runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]),
        throwsExceptionWith('No persistent state file found at $stateFile'),
      );
    });

    group('APPLY_ENGINE_CHERRYPICKS to CODESIGN_ENGINE_BINARIES', () {
      test('does not prompt user and updates currentPhase if there are no engine cherrypicks', () async {
        final FakeProcessManager processManager = FakeProcessManager.list(
          <FakeCommand>[],
        );
        final FakePlatform platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
        final pb.ConductorState state = pb.ConductorState(
          currentPhase: ReleasePhase.APPLY_ENGINE_CHERRYPICKS,
        );
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(finalState.currentPhase, ReleasePhase.CODESIGN_ENGINE_BINARIES);
        expect(stdio.error, isEmpty);
      });

      test('updates lastPhase if user responds yes', () async {
        const String remoteUrl = 'https://githost.com/org/repo.git';
        stdio.stdin.add('y');
        final FakeProcessManager processManager = FakeProcessManager.list(
          <FakeCommand>[],
        );
        final FakePlatform platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
        final pb.ConductorState state = pb.ConductorState(
          engine: pb.Repository(
            cherrypicks: <pb.Cherrypick>[
              pb.Cherrypick(
                trunkRevision: 'abc123',
                state: pb.CherrypickState.PENDING,
              ),
            ],
            mirror: pb.Remote(url: remoteUrl),
          ),
          currentPhase: ReleasePhase.APPLY_ENGINE_CHERRYPICKS,
        );
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(stdio.stdout, contains(
                'Are you ready to push your engine branch to the repository $remoteUrl? (y/n) '));
        expect(finalState.currentPhase, ReleasePhase.CODESIGN_ENGINE_BINARIES);
        expect(stdio.error, isEmpty);
      });
    });

    group('CODESIGN_ENGINE_BINARIES to APPLY_FRAMEWORK_CHERRYPICKS', () {
      pb.ConductorState state;
      FakeProcessManager processManager;
      FakePlatform platform;

      setUp(() {
        state = pb.ConductorState(
          engine: pb.Repository(
            cherrypicks: <pb.Cherrypick>[
              pb.Cherrypick(
                trunkRevision: 'abc123',
                state: pb.CherrypickState.PENDING,
              ),
            ],
          ),
          currentPhase: ReleasePhase.CODESIGN_ENGINE_BINARIES,
        );

        processManager = FakeProcessManager.empty();

        platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
      });

      test('does not update currentPhase if user responds no', () async {
        stdio.stdin.add('n');
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(stdio.stdout, contains('Has CI passed for the engine PR and binaries been codesigned? (y/n) '));
        expect(finalState.currentPhase, ReleasePhase.CODESIGN_ENGINE_BINARIES);
        expect(stdio.error.contains('Aborting command.'), true);
      });

      test('updates currentPhase if user responds yes', () async {
        stdio.stdin.add('y');
        final FakePlatform platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(stdio.stdout, contains('Has CI passed for the engine PR and binaries been codesigned? (y/n) '));
        expect(finalState.currentPhase, ReleasePhase.APPLY_FRAMEWORK_CHERRYPICKS);
      });
    });

    group('APPLY_FRAMEWORK_CHERRYPICKS to PUBLISH_VERSION', () {
      const String remoteUrl = 'https://githost.com/org/repo.git';
      FakeProcessManager processManager;
      FakePlatform platform;
      pb.ConductorState state;

      setUp(() {
        processManager = FakeProcessManager.empty();
        platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
        state = pb.ConductorState(
          framework: pb.Repository(
            cherrypicks: <pb.Cherrypick>[
              pb.Cherrypick(
                trunkRevision: 'abc123',
                state: pb.CherrypickState.PENDING,
              ),
            ],
            mirror: pb.Remote(url: remoteUrl),
          ),
          currentPhase: ReleasePhase.APPLY_FRAMEWORK_CHERRYPICKS,
        );
      });

      test('does not prompt user and updates state.currentPhase from APPLY_FRAMEWORK_CHERRYPICKS to PUBLISH_VERSION if there are no framework cherrypicks', () async {
        final pb.ConductorState state = pb.ConductorState(
          currentPhase: ReleasePhase.APPLY_FRAMEWORK_CHERRYPICKS,
        );
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(stdio.stdout, isNot(contains('Did you apply all framework cherrypicks? (y/n) ')));
        expect(finalState.currentPhase, ReleasePhase.PUBLISH_VERSION);
        expect(stdio.error, isEmpty);
      });

      test('does not update state.currentPhase from APPLY_FRAMEWORK_CHERRYPICKS if user responds no', () async {
        stdio.stdin.add('n');
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(stdio.stdout, contains('Are you ready to push your framework branch to the repository $remoteUrl? (y/n) '));
        expect(stdio.error, contains('Aborting command.'));
        expect(finalState.currentPhase, ReleasePhase.APPLY_FRAMEWORK_CHERRYPICKS);
      });

      test('updates state.currentPhase from APPLY_FRAMEWORK_CHERRYPICKS to PUBLISH_VERSION if user responds yes', () async {
        stdio.stdin.add('y');
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(finalState.currentPhase, ReleasePhase.PUBLISH_VERSION);
        expect(stdio.stdout, contains('Are you ready to push your framework branch to the repository $remoteUrl? (y/n)'));
      });
    });

    group('PUBLISH_VERSION to PUBLISH_CHANNEL', () {
      const String remoteName = 'upstream';
      const String releaseVersion = '1.2.0-3.0.pre';
      pb.ConductorState state;
      FakePlatform platform;

      setUp(() {
        state = pb.ConductorState(
          currentPhase: ReleasePhase.PUBLISH_VERSION,
          framework: pb.Repository(
            candidateBranch: candidateBranch,
            upstream: pb.Remote(url: FrameworkRepository.defaultUpstream),
          ),
          releaseVersion: releaseVersion,
        );
        platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
      });

      test('does not update state.currentPhase if user responds no', () async {
        stdio.stdin.add('n');
        final FakeProcessManager processManager = FakeProcessManager.list(
          <FakeCommand>[
            const FakeCommand(
              command: <String>['git', 'fetch', 'upstream'],
            ),
            const FakeCommand(
              command: <String>['git', 'checkout', '$remoteName/$candidateBranch'],
            ),
            const FakeCommand(
              command: <String>['git', 'rev-parse', 'HEAD'],
              stdout: revision1,
            ),
          ],
        );
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(processManager, hasNoRemainingExpectations);
        expect(stdio.stdout, contains('Are you ready to tag commit $revision1 as $releaseVersion'));
        expect(stdio.error, contains('Aborting command.'));
        expect(finalState.currentPhase, ReleasePhase.PUBLISH_VERSION);
        expect(finalState.logs, stdio.logs);
      });

      test('updates state.currentPhase if user responds yes', () async {
        stdio.stdin.add('y');
        final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
          const FakeCommand(
            command: <String>['git', 'fetch', 'upstream'],
          ),
          const FakeCommand(
            command: <String>['git', 'checkout', '$remoteName/$candidateBranch'],
          ),
          const FakeCommand(
            command: <String>['git', 'rev-parse', 'HEAD'],
            stdout: revision1,
          ),
          const FakeCommand(
            command: <String>['git', 'tag', releaseVersion, revision1],
          ),
          const FakeCommand(
            command: <String>['git', 'push', remoteName, releaseVersion],
          ),
        ]);
        final FakePlatform platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(processManager, hasNoRemainingExpectations);
        expect(finalState.currentPhase, ReleasePhase.PUBLISH_CHANNEL);
        expect(stdio.stdout, contains('Are you ready to tag commit $revision1 as $releaseVersion'));
        expect(finalState.logs, stdio.logs);
      });
    });

    group('PUBLISH_CHANNEL to RELEASE_COMPLETED', () {
      const String remoteName = 'upstream';
      const String releaseVersion = '1.2.0-3.0.pre';
      const String releaseChannel = 'beta';
      pb.ConductorState state;
      FakePlatform platform;

      setUp(() {
        state = pb.ConductorState(
          currentPhase: ReleasePhase.PUBLISH_CHANNEL,
          framework: pb.Repository(
            candidateBranch: candidateBranch,
            upstream: pb.Remote(url: FrameworkRepository.defaultUpstream),
          ),
          releaseChannel: releaseChannel,
          releaseVersion: releaseVersion,
        );
        platform = FakePlatform(
          environment: <String, String>{
            'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
          },
          operatingSystem: localOperatingSystem,
          pathSeparator: localPathSeparator,
        );
      });

      test('does not update currentPhase if user responds no', () async {
        stdio.stdin.add('n');
        final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
          const FakeCommand(
            command: <String>['git', 'fetch', 'upstream'],
          ),
          const FakeCommand(
            command: <String>['git', 'checkout', '$remoteName/$candidateBranch'],
          ),
          const FakeCommand(
            command: <String>['git', 'rev-parse', 'HEAD'],
            stdout: revision1,
          ),
        ]);
        writeStateToFile(
          fileSystem.file(stateFile),
          state,
          <String>[],
        );
        final Checkouts checkouts = Checkouts(
          fileSystem: fileSystem,
          parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
          platform: platform,
          processManager: processManager,
          stdio: stdio,
        );
        final CommandRunner<void> runner = createRunner(checkouts: checkouts);
        await runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]);

        final pb.ConductorState finalState = readStateFromFile(
          fileSystem.file(stateFile),
        );

        expect(processManager, hasNoRemainingExpectations);
        expect(stdio.error, contains('Aborting command.'));
        expect(
          stdio.stdout,
          contains('About to execute command: `git push ${FrameworkRepository.defaultUpstream} $revision1:$releaseChannel`'),
        );
        expect(finalState.currentPhase, ReleasePhase.PUBLISH_CHANNEL);
      });
    });

    test('throws exception if state.currentPhase is RELEASE_COMPLETED', () async {
      final FakeProcessManager processManager = FakeProcessManager.empty();
      final FakePlatform platform = FakePlatform(
        environment: <String, String>{
          'HOME': <String>['path', 'to', 'home'].join(localPathSeparator),
        },
        operatingSystem: localOperatingSystem,
        pathSeparator: localPathSeparator,
      );
      final pb.ConductorState state = pb.ConductorState(
        currentPhase: ReleasePhase.RELEASE_COMPLETED,
      );
      writeStateToFile(
        fileSystem.file(stateFile),
        state,
        <String>[],
      );
      final Checkouts checkouts = Checkouts(
        fileSystem: fileSystem,
        parentDirectory: fileSystem.directory(checkoutsParentDirectory)..createSync(recursive: true),
        platform: platform,
        processManager: processManager,
        stdio: stdio,
      );
      final CommandRunner<void> runner = createRunner(checkouts: checkouts);
      expect(
        () async => runner.run(<String>[
          'next',
          '--$kStateOption',
          stateFile,
        ]),
        throwsExceptionWith('This release is finished.'),
      );
    });
  }, onPlatform: <String, dynamic>{
    'windows': const Skip('Flutter Conductor only supported on macos/linux'),
  });
}
