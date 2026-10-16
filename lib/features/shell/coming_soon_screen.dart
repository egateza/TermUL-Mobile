import 'package:flutter/material.dart';

import '../../core/theme/termul_theme.dart';
import '../../shared/widgets/termul_banner.dart';

/// Layar sementara untuk tab yang belum dibuat (SFTP, Snippet). Desain tetap memuat tab-nya; layar ini hanya
/// menyampaikan dengan kata bahwa fiturnya belum tersedia.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.heading, required this.body});

  final String title;
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                TermulSpacing.space8,
                landscape ? TermulSpacing.space3 : TermulSpacing.space8,
                TermulSpacing.space8,
                landscape ? TermulSpacing.space3 : TermulSpacing.space5,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: (landscape ? TermulText.h2 : TermulText.h1).copyWith(color: TermulPalette.ink),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space8),
              child: TermulBanner(tone: BannerTone.info, title: heading, child: Text(body)),
            ),
          ],
        ),
      ),
    );
  }
}
