import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';

/// Composition root for the mobile app.
///
/// Deliberately empty of behaviour. The app is a thin cache over server truth
/// and owns no rules: every privacy and trust decision is made server-side and
/// rendered here (`docs/v3/11_SECURITY.md` §2).
///
/// Note what is *not* imported: `package:ekipa_core/matching.dart`. Directive
/// D9 keeps the matcher out of every user build, and `tools/lint` fails the
/// build if it ever appears here.
void main() => runApp(const EkipaApp());

/// The application shell.
class EkipaApp extends StatelessWidget {
  /// Creates the shell.
  const EkipaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ekipa',
    debugShowCheckedModeBanner: false,
    theme: EkipaTheme.dark(),
    home: const _Placeholder(),
  );
}

/// What the app shows until P1 puts identity and availability here.
///
/// It is built from the design system rather than from ad-hoc styling, so that
/// the very first screen in the repository already cannot drift from the
/// tokens — which is the failure the v1 kit had at six screens.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => EkipaScreen(
    title: 'ekipa',
    lede: 'Four people, ninety minutes, somewhere in town.',
    action: const EkipaButton(label: 'Get started', onPressed: null),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: staggered(const [
        EkipaCard(
          child: FactStrip([
            Fact('When', 'Thu 17:30'),
            Fact('Where', 'Centre'),
            Fact('Who', '4 people'),
          ]),
        ),
        SizedBox(height: ZarSpace.md),
        Text(
          'Identity, availability and the hangout lifecycle land in P1 and P2. '
          'This screen exists so the shell is built on the design system from '
          'the first commit rather than restyled later.',
          style: ZarType.caption,
        ),
      ]),
    ),
  );
}
