import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import 'app_text.dart';
import 'pressable_scale.dart';

enum EkipaButtonVariant { primary, secondary, ghost, danger }

/// The single button primitive. Primary is a moss gradient with a genuine
/// glow shadow. When [celebrate] is set — the single real commitment
/// action in the app — it switches to the ember gradient instead, since
/// ember is reserved for exactly two moments: arrival and commitment.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EkipaButtonVariant.primary,
    this.loading = false,
    this.disabled = false,
    this.celebrate = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final EkipaButtonVariant variant;
  final bool loading;
  final bool disabled;

  /// Success haptic on press — reserve for real commitments (e.g. "Yes, I'll come").
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDisabled = disabled || loading;

    final tone = switch (variant) {
      EkipaButtonVariant.primary => EkipaTone.onBrand,
      EkipaButtonVariant.danger => EkipaTone.danger,
      _ => EkipaTone.normal,
    };

    return PressableScale(
      haptic: !celebrate,
      onTap: isDisabled
          ? null
          : () {
              if (celebrate) HapticFeedback.mediumImpact();
              onPressed?.call();
            },
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: EkipaSpace.xl),
          alignment: Alignment.center,
          decoration: _decoration(variant, c, celebrate),
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: variant == EkipaButtonVariant.primary
                        ? c.textOnBrand
                        : c.moss,
                  ),
                )
              : AppText(
                  label,
                  variant: EkipaTextVariant.bodyStrong,
                  tone: tone,
                ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(EkipaButtonVariant variant, EkipaColors c, bool celebrate) {
    switch (variant) {
      case EkipaButtonVariant.primary:
        final glow = celebrate ? c.ember : c.moss;
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: celebrate
                ? [c.ember, c.emberSoft]
                : [c.mossGlow.withValues(alpha: 0.9), c.moss],
          ),
          borderRadius: BorderRadius.circular(EkipaRadius.lg),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.45),
              blurRadius: 26,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        );
      case EkipaButtonVariant.secondary:
        return BoxDecoration(
          color: c.glass,
          borderRadius: BorderRadius.circular(EkipaRadius.lg),
          border: Border.all(color: c.line, width: 1),
        );
      case EkipaButtonVariant.ghost:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(EkipaRadius.lg),
          border: Border.all(color: c.lineSoft, width: 1),
        );
      case EkipaButtonVariant.danger:
        return BoxDecoration(
          color: c.glass,
          borderRadius: BorderRadius.circular(EkipaRadius.lg),
          border: Border.all(color: c.danger.withValues(alpha: 0.4), width: 1),
        );
    }
  }
}
