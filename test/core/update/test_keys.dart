import 'package:termul_mobile/core/update/manifest.dart';

/// Kunci uji (bukan kunci rilis): seed tetap supaya tes deterministik.
final testSeed = List<int>.generate(32, (i) => i + 1);
final testPublicKey = publicKeyOf(testSeed);
