import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_providers.dart';
import 'boot_error_app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final deps = await bootstrap();
    runApp(ProviderScope(overrides: deps.overrides, child: const TermulApp()));
  } on Object {
    runApp(const BootErrorApp());
  }
}
