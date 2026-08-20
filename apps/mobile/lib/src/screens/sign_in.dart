import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/identity/identity_verifier.dart';
import 'package:mobile/src/state/providers.dart';

/// Proving you are a person.
///
/// **Intention — the screen does not know which method is in use.** Everything
/// it renders comes from the [IdentityVerifier]: the prompt, the field's label,
/// whether there is a second step. Swapping the `.edu.hr` code path for
/// AAI@EduHr costs one line at the composition root and touches nothing here.
///
/// **It handles a two-step flow even when the current method has one.** The
/// cheapest way to be sure the code path works when it matters is to have it be
/// the only path — so `begin` returns a sealed [VerificationStep] and this
/// screen switches on it, whether or not today's verifier ever returns
/// `CodeRequired`.
///
/// **What we keep is stated before signup, not after.** `02_DOMAIN.md §6` lists
/// exactly seven fields. A person deciding whether to sign up should be able to
/// read that list on the screen where they decide, not find it in a policy
/// afterwards.
class SignInScreen extends ConsumerStatefulWidget {
  /// The sign-in screen.
  const SignInScreen({required this.onVerified, super.key});

  /// Called with the verified identity.
  final void Function(VerifiedIdentity identity) onVerified;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _challengeId;
  String? _sentTo;
  String? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final verifier = ref.read(verifierProvider);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      // Two calls with different return shapes, so the branch is on which
      // question is outstanding rather than on a flag somebody has to keep in
      // step with the screen.
      if (_challengeId case final String challenge) {
        final done = await verifier.complete(
          challengeId: challenge,
          code: _code.text.trim(),
        );
        switch (done) {
          case Ok(:final value):
            widget.onVerified(value);
          case Err(:final error):
            setState(() => _failure = error);
        }
        return;
      }

      final started = await verifier.begin(_subject.text.trim());
      switch (started) {
        case Err(:final error):
          setState(() => _failure = error);
        case Ok(value: final CodeRequired step):
          setState(() {
            _challengeId = step.challengeId;
            _sentTo = step.sentTo;
          });
        case Ok(value: final Verified step):
          widget.onVerified(step.identity);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifier = ref.watch(verifierProvider);
    final awaitingCode = _challengeId != null;

    return EkipaScreen(
      title: awaitingCode ? 'Check your email' : 'ekipa',
      lede: awaitingCode
          ? 'Six digits, sent to ${_sentTo ?? 'your address'}. It is good for '
                'ten minutes.'
          : verifier.prompt,
      action: EkipaButton(
        label: awaitingCode ? 'Confirm' : 'Continue',
        busy: _busy,
        onPressed: _busy ? null : _submit,
      ),
      secondaryAction: awaitingCode
          ? EkipaButton(
              label: 'Use a different address',
              tone: EkipaButtonTone.quiet,
              onPressed: () => setState(() {
                _challengeId = null;
                _code.clear();
              }),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            awaitingCode ? 'CODE' : verifier.subjectLabel.toUpperCase(),
            style: ZarType.label.copyWith(
              color: ZarColors.inkFaint,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: ZarSpace.xs),
          _Field(
            controller: awaitingCode ? _code : _subject,
            hint: awaitingCode ? '000000' : verifier.subjectHint,
            mono: awaitingCode,
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_failure != null) ...[
            const SizedBox(height: ZarSpace.sm),
            Text(
              _failure!,
              style: ZarType.body.copyWith(color: ZarColors.rose),
            ),
          ],
          const SizedBox(height: ZarSpace.xxl),
          if (!awaitingCode) const _WhatWeKeep(),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.mono,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool mono;
  final void Function(String value) onSubmitted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZarColors.surface,
      borderRadius: ZarRadius.allMd,
      border: Border.all(color: ZarColors.hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZarSpace.md,
        vertical: ZarSpace.xs,
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: (mono ? ZarType.mono : ZarType.body).copyWith(
          color: ZarColors.ink,
          letterSpacing: mono ? 6 : null,
        ),
        cursorColor: ZarColors.ember,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: (mono ? ZarType.mono : ZarType.body).copyWith(
            color: ZarColors.inkFaint,
            letterSpacing: mono ? 6 : null,
          ),
        ),
      ),
    ),
  );
}

/// The seven fields, before signup rather than after.
class _WhatWeKeep extends StatelessWidget {
  const _WhatWeKeep();

  /// Everything the product stores about a person, said in their words.
  ///
  /// **This is the whole list, and it has to stay the whole list.**
  /// `02_DOMAIN.md §6` is the specification; if a column is added there and a
  /// line is not added here, this screen is a lie told at the exact moment
  /// somebody is deciding whether to trust it. No photo, no bio, no surname, no
  /// address, no location trace, no messages — because there are no such
  /// columns, not because we hide them.
  ///
  /// Each entry is a named constant rather than a wrapped literal inside the
  /// list: two adjacent strings in a list literal are one missing comma away
  /// from being two entries, and the analyzer is right to refuse them.
  static const String _name =
      'Your first name and the last letter of your surname. Other people '
      'see “Ana ····K”.';
  static const String _hash =
      'A one-way code derived from your university identity, so a ban cannot '
      'be walked around with a new account.';
  static const String _gender =
      'Which gender you told us, for building the group.';
  static const String _anchor =
      'Roughly where you set out from, snapped to a 500-metre grid.';
  static const String _evenings = 'Which evenings you said you were free.';
  static const String _afterwards =
      'Whether you turned up, and what people answered afterwards.';
  static const String _push = 'A push token, so we can ask you on the morning.';

  static const List<String> _kept = [
    _name,
    _hash,
    _gender,
    _anchor,
    _evenings,
    _afterwards,
    _push,
  ];

  @override
  Widget build(BuildContext context) => EkipaCard(
    tone: EkipaCardTone.quiet,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What we keep', style: ZarType.bodyStrong),
        const SizedBox(height: ZarSpace.sm),
        for (final line in _kept) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 9, right: ZarSpace.xs),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZarColors.inkFaint,
                ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: ZarType.caption.copyWith(color: ZarColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZarSpace.xs),
        ],
        const SizedBox(height: ZarSpace.xs),
        Text(
          'No photo. No bio. No surname. No messages — there is no chat. No '
          'location trace.',
          style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
        ),
      ],
    ),
  );
}
