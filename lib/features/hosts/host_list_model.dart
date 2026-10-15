import '../../core/models/host_profile.dart';
import '../../core/models/profile_snapshot.dart';

enum HostFilter { all, favorites }

/// Satu grup yang ditampilkan: [path] kosong berarti host tanpa grup.
class HostGroupView {
  const HostGroupView(this.path, this.hosts);

  final String path;
  final List<HostProfile> hosts;
}

/// Mengelompokkan host untuk layar daftar. Hanya grup yang punya host yang muncul, terurut menurut path
/// dengan host tanpa grup di akhir; host di dalam grup terurut nama tanpa membedakan huruf besar kecil.
/// [query] mencocokkan nama, `user@host`, dan port. Status online tidak dipakai di sini: statusnya cache dan
/// belum ada pengecekan, jadi filter "Online" belum disediakan.
List<HostGroupView> buildHostGroups(ProfileSnapshot snapshot, {String query = '', HostFilter filter = HostFilter.all}) {
  final q = query.trim().toLowerCase();
  bool matches(HostProfile p) {
    if (filter == HostFilter.favorites && !snapshot.isFavorite(p.id)) return false;
    if (q.isEmpty) return true;
    final text = '${p.name} ${p.username}@${p.host}:${p.port}'.toLowerCase();
    return text.contains(q);
  }

  final result = <HostGroupView>[];
  final root = <HostProfile>[];
  for (final group in snapshot.allGroups) {
    final hosts = snapshot.profilesIn(group).where(matches).toList();
    if (hosts.isNotEmpty) result.add(HostGroupView(group, hosts));
  }
  root.addAll(snapshot.profilesIn('').where(matches));
  if (root.isNotEmpty) result.add(HostGroupView('', root));
  return result;
}
