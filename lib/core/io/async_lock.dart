import 'dart:async';

/// Kunci async sederhana: tugas dijalankan satu per satu sesuai urutan masuk.
/// Dipakai agar mutasi penyimpanan tidak saling menimpa walau ada `await` di tengahnya.
class AsyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = Completer<T>();
    final previous = _tail;
    _tail = result.future.then<void>((_) {}, onError: (Object _) {});
    previous.then((_) async {
      try {
        result.complete(await task());
      } catch (e, s) {
        result.completeError(e, s);
      }
    });
    return result.future;
  }
}
