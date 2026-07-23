import * as Haptics from 'expo-haptics';

/**
 * Thin, intention-named haptics. Kept gentle and sparing — a quiet, embodied
 * "yes, that registered", never a game buzzer. All calls are fire-and-forget
 * and safe to ignore failures (e.g. on web or unsupported devices).
 */

export function tapSelect() {
  Haptics.selectionAsync().catch(() => {});
}

export function tapLight() {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
}

export function tapSoft() {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Soft).catch(() => {});
}

export function confirm() {
  Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
}
