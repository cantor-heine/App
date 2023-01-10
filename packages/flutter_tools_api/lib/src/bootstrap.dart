import 'dart:isolate';

import 'common.dart';
import 'extension.dart';

class _ExtensionServer {
  _ExtensionServer(this._sendPort, this._extensions) {
    _receivePort.listen(_messageHandler);

    _sendPort.send(_receivePort.sendPort);
    for (final Extension extension in _extensions) {
      extension.registerHandlers(_registeredHandlers);
    }
  }

  final ReceivePort _receivePort = ReceivePort();
  final SendPort _sendPort;
  final List<Extension> _extensions;
  void send(Object message) => _sendPort.send(message);
  final Map<Type, List<void Function(Object?)>> _registeredHandlers = <Type, List<void Function(Object?)>>{};

  void _messageHandler(Object? message) {
    if (message is RequestWrapper) {
      final List<RequestHandler>? handlers = _registeredHandlers[message.request.runtimeType];
      if (handlers == null) {
        print('no-op for type ${message.request.runtimeType}');
        return;
      }
    } else {
      throw UnimplementedError('Do not know how to handle a ${message.runtimeType}');
    }
  }
}

/// TODO
typedef ExtensionsIsolateBootstrap = void Function(SendPort);

/// Returns a function that the child isolate can be spawned with.
ExtensionsIsolateBootstrap bootstrapFactory(List<Extension> extensions) {
  return (SendPort sendPort) {
    final _ExtensionServer server = _ExtensionServer(sendPort, extensions);
  };
}
