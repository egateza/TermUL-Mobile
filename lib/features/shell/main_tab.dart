import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab yang sedang aktif di `MainShell` (`hosts`, `sessions`, `snippets`, `streak`, `settings`). Bisa diganti dari
/// luar bar navigasi, mis. chip streak di header Host membuka tab Streak.
class MainTabNotifier extends Notifier<String> {
  @override
  String build() => 'hosts';

  void select(String id) => state = id;
}

final mainTabProvider = NotifierProvider<MainTabNotifier, String>(MainTabNotifier.new);
