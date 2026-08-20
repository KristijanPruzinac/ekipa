import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import 'activity_icon.dart';
import 'app_text.dart';
import 'pressable_scale.dart';

/// A small glass chip — an activity label, optionally selectable and
/// optionally carrying a hand-drawn activity icon instead of emoji.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.iconSlug,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? iconSlug;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        vertical: EkipaSpace.sm + 2,
        horizontal: EkipaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: selected ? c.moss.withValues(alpha: 0.14) : c.glass,
        borderRadius: BorderRadius.circular(EkipaRadius.pill),
        border: Border.all(
          color: selected ? c.moss.withValues(alpha: 0.5) : c.line,
          width: 1.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconSlug != null) ...[
            ActivityIcon(
              iconSlug!,
              size: 15,
              color: selected ? c.mossGlow : c.inkFaint,
            ),
            const SizedBox(width: EkipaSpace.xs + 2),
          ],
          AppText(
            label,
            variant: EkipaTextVariant.calloutStrong,
            tone: selected ? EkipaTone.mossGlow : EkipaTone.soft,
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return PressableScale(
      haptic: false,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: chip,
    );
  }
}
