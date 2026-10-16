import 'package:termul_mobile/core/platform/keepalive_platform.dart';

/// Foreground service palsu yang mencatat panggilan.
class FakeKeepAlive implements KeepAlivePlatform {
  final updates = <({String title, String text})>[];
  int stops = 0;
  int settingsOpened = 0;
  bool enabled = true;
  bool grantOnRequest = true;
  Object? updateError;
  void Function()? disconnectAll;

  @override
  Future<void> update({
    required String title,
    required String text,
    required String actionLabel,
    required String channelName,
  }) async {
    if (updateError != null) throw updateError!;
    updates.add((title: title, text: text));
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestNotifications() async {
    if (grantOnRequest) enabled = true;
    return enabled;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  void setDisconnectAllHandler(void Function()? handler) => disconnectAll = handler;
}
