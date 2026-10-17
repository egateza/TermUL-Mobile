import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../io/async_lock.dart';
import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../models/host_profile.dart';
import '../../models/profile_snapshot.dart';
import '../host_repository.dart';
import '../load_result.dart';

/// [HostRepository] di atas satu berkas JSON, ditulis atomik. Skema `profiles.json` sama dengan desktop.
class JsonHostRepository implements HostRepository {
  JsonHostRepository(this._file, {this._writer = _defaultWriter});

  final File _file;
  final AtomicWriter _writer;
  final _lock = AsyncLock();
  final _controller = StreamController<ProfileSnapshot>.broadcast();
  ProfileSnapshot _snapshot = ProfileSnapshot.empty();

  static Future<void> _defaultWriter(File f, List<int> b) => writeAtomic(f, b);

  @override
  ProfileSnapshot get snapshot => _snapshot;

  @override
  Stream<ProfileSnapshot> get changes => _controller.stream;

  @override
  Future<LoadResult> load() => _lock.run(() async {
    final loaded = await loadJsonOrQuarantine<ProfileSnapshot>(
      _file,
      parse: ProfileSnapshot.fromJson,
      empty: ProfileSnapshot.empty(),
    );
    _snapshot = loaded.value;
    _controller.add(_snapshot);
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  });

  @override
  Future<ProfileSnapshot> save(HostProfile profile) => _mutate((s) => s.withProfile(profile));

  @override
  Future<ProfileSnapshot> delete(String id) => _mutate((s) => s.find(id) == null ? s : s.withoutProfile(id));

  @override
  Future<ProfileSnapshot> setFavorite(String id, {required bool favorite}) => _mutate((s) {
    if (s.find(id) == null || s.isFavorite(id) == favorite) return s;
    return s.withFavorite(id, favorite: favorite);
  });

  @override
  Future<ProfileSnapshot> markUsed(String id) => _mutate((s) {
    if (s.find(id) == null || (s.recent.isNotEmpty && s.recent.first == id.toLowerCase())) {
      return s;
    }
    return s.withUsed(id);
  });

  @override
  Future<ProfileSnapshot> clearRecent() => _mutate((s) => s.recent.isEmpty ? s : s.withoutRecent());

  @override
  Future<ProfileSnapshot> update(ProfileSnapshot Function(ProfileSnapshot current) change) => _mutate(change);

  @override
  Future<ProfileSnapshot> addGroup(String group) => _mutate((s) => s.withGroups([...s.groups, group]));

  @override
  Future<ProfileSnapshot> deleteGroup(String group) {
    final g = HostProfile.normalizeGroup(group);
    return _mutate((s) {
      if (s.profiles.any((p) => _sameOrChild(p.group, g))) {
        throw StateError("Grup '$g' masih berisi profil");
      }
      return s.withGroups([
        for (final x in s.groups)
          if (!_sameOrChild(x, g)) x,
      ]);
    });
  }

  @override
  Future<ProfileSnapshot> renameGroup(String from, String to) {
    final src = HostProfile.normalizeGroup(from);
    final dst = HostProfile.normalizeGroup(to);
    if (src.isEmpty) throw ArgumentError('Grup root tidak bisa di-rename');
    return _mutate((s) {
      var result = s.withGroups([for (final g in s.groups) _rebase(g, src, dst)]);
      for (final p in s.profiles) {
        if (_sameOrChild(p.group, src)) {
          result = result.withProfile(p.withGroup(_rebase(p.group, src, dst)));
        }
      }
      return result;
    });
  }

  Future<ProfileSnapshot> _mutate(ProfileSnapshot Function(ProfileSnapshot) change) => _lock.run(() async {
    final updated = change(_snapshot);
    if (identical(updated, _snapshot)) return updated;
    const encoder = JsonEncoder.withIndent('  ');
    await _writer(_file, utf8.encode(encoder.convert(updated.toJson())));
    _snapshot = updated;
    _controller.add(updated);
    return updated;
  });

  static bool _sameOrChild(String group, String parent) => group == parent || group.startsWith('$parent/');

  static String _rebase(String group, String src, String dst) {
    if (!_sameOrChild(group, src)) return group;
    return HostProfile.normalizeGroup(dst + group.substring(src.length));
  }
}
