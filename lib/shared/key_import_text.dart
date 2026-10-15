import '../core/keys/private_key_inspector.dart';
import '../l10n/app_localizations.dart';

/// Teks galat impor kunci, dipakai form host dan layar "Rahasia hilang".
String keyErrorText(AppLocalizations l, KeyImportException e) => switch (e.problem) {
  KeyProblem.notAKey => l.keyErrNotAKey,
  KeyProblem.notPem => l.keyErrNotPem,
  KeyProblem.pkcs8Unsupported => l.keyErrPkcs8,
  KeyProblem.unsupportedType => l.keyErrType(e.detail ?? ''),
  KeyProblem.malformed => l.keyErrMalformed,
  KeyProblem.wrongPassphrase => l.errPassphraseWrong,
};

String keyTypeLabel(String pemType) => switch (pemType) {
  'OPENSSH PRIVATE KEY' => 'OpenSSH',
  'RSA PRIVATE KEY' => 'RSA',
  'EC PRIVATE KEY' => 'EC',
  _ => pemType,
};
