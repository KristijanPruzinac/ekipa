import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/screen.dart';

/// The one thing asked of a new user before Welcome: a phone number, then
/// the code sent to it. No name, no city, no preferences — see docs/PLAN.md
/// Phase 1. The router only routes here when a Supabase project is actually
/// configured (see [isBackendConfigured] in router.dart's redirect).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        await repository.requestPhoneCode(_phoneController.text.trim());
        if (mounted) setState(() => _codeSent = true);
      } else {
        await repository.verifyPhoneCode(
          phone: _phoneController.text.trim(),
          code: _codeController.text.trim(),
        );
        // A successful sign-in flips supabase.auth's session stream, which
        // the router listens to and redirects off this screen on its own.
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _codeSent
              ? "That code didn't match. Try again."
              : "Couldn't send that code — check the number and try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Screen(
      scroll: false,
      backgroundAsset: 'assets/backgrounds/auth_dawn.jpg',
      scrim: 0.12,
      footer: AppButton(
        label: _codeSent ? 'Confirm code' : 'Send code',
        loading: _loading,
        onPressed: _loading ? null : _submit,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Appear(
            child: AppText("What's your number?", variant: EkipaTextVariant.title),
          ),
          const SizedBox(height: EkipaSpace.sm),
          const Appear(
            delay: Duration(milliseconds: 80),
            child: AppText(
              "We text you a code to sign in. After that, just a minute of "
              "quick logistics — never a profile to fill out.",
              tone: EkipaTone.soft,
            ),
          ),
          const SizedBox(height: EkipaSpace.xl),
          Appear(
            delay: const Duration(milliseconds: 140),
            child: AppCard(
              child: _codeSent
                  ? TextField(
                      key: const ValueKey('code'),
                      controller: _codeController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: c.ink, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: '6-digit code',
                        hintStyle: TextStyle(color: c.inkFaint),
                        border: InputBorder.none,
                      ),
                    )
                  : TextField(
                      key: const ValueKey('phone'),
                      controller: _phoneController,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: c.ink, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: '+385 91 234 5678',
                        hintStyle: TextStyle(color: c.inkFaint),
                        border: InputBorder.none,
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: EkipaSpace.md),
            AppText(_error!, tone: EkipaTone.danger, center: true),
          ],
        ],
      ),
    );
  }
}
