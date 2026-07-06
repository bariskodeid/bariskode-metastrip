import 'dart:async';
import 'dart:isolate';

Future<T> runOnWorker<T>(FutureOr<T> Function() action) {
  return Isolate.run(action);
}
