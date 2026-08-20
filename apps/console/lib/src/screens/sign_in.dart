import 'package:console/src/theme/console_theme.dart';
import 'package:console/src/widgets/console_chrome.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signing in to the console.
///
/// **Intention — this screen does not grant anything.** It exchanges a password
/// for a session, and that is all. Whether the session may do anything is
/// decided afterwards, by the database, when `admin_role()` is asked. A sign-in
/// that succeeds here and lands on "the database does not recognise you" is the
/// system working, not a bug.
///
/// **The second factor is not enforced here either.** It cannot be: a client
/// that decides when MFA is required is a client an attacker can edit. The
/// gate lives in `admin_role()`, which returns nothing unless the JWT carries
/// `aal2`. This screen tells the operator that, so the refusal is not a
/// surprise — but the telling is a courtesy and the refusal is the control.
class SignInScreen extends StatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      // Supabase's own words. A console that rewrote "Invalid login
      // credentials" into something friendlier would also be hiding the
      // difference between a wrong password and a disabled account.
      setState(() => _failure = error.message);
    } on Object catch (error) {
      setState(() => _failure = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZarColors.ground,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(ZarSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ekipa console', style: ZarType.title),
              const SizedBox(height: ZarSpace.xs),
              const Text(
                'A second factor is required. It is checked by the database, '
                'so signing in without one gets you a session that can read '
                'nothing.',
                style: ConsoleType.note,
              ),
              const SizedBox(height: ZarSpace.xl),
              _Field(label: 'Email', controller: _email),
              const SizedBox(height: ZarSpace.md),
              _Field(label: 'Password', controller: _password, obscure: true),
              if (_failure case final String message) ...[
                const SizedBox(height: ZarSpace.md),
                Verbatim(message, tone: ZarColors.rose),
              ],
              const SizedBox(height: ZarSpace.xl),
              EkipaButton(
                label: _busy ? 'Signing in…' : 'Sign in',
                onPressed: _busy ? null : _signIn,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: ConsoleType.columnHead),
      const SizedBox(height: ZarSpace.xs),
      TextField(
        controller: controller,
        obscureText: obscure,
        style: ZarType.body,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.all(ZarSpace.sm),
          enabledBorder: OutlineInputBorder(
            borderRadius: ZarRadius.allSm,
            borderSide: BorderSide(color: ZarColors.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: ZarRadius.allSm,
            borderSide: BorderSide(color: ZarColors.focus),
          ),
        ),
      ),
    ],
  );
}
