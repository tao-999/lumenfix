// lib/services/thumb_cache.dart
import 'dart:typed_data';

class ThumbCache {
  static final ThumbCache I = ThumbCache._();
  ThumbCache._();

  final Map<String, Uint8List> _mem = {};
  final Map<String, Future<Uint8List>> _inflight = {};

  Future<Uint8List> getOrCompute(
      String key,
      Future<Uint8List> Function() builder,
      ) {
    final hit = _mem[key];
    if (hit != null) return Future.value(hit);
    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final fut = builder().then((b) {
      _mem[key] = b;
      _inflight.remove(key);
      return b;
    });
    _inflight[key] = fut;
    return fut;
  }

  Uint8List? peek(String key) => _mem[key];
  void clear() => _mem.clear();
}
