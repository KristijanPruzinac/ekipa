import type { ReactNode } from 'react';
import { useRef } from 'react';
import { Animated, Pressable, type ViewStyle } from 'react-native';
import { tapLight } from '@/lib/haptics';
import { motion } from '@/theme';

interface PressableScaleProps {
  children: ReactNode;
  onPress?: () => void;
  disabled?: boolean;
  /** Gentle haptic tick on press (default true). */
  haptic?: boolean;
  style?: ViewStyle;
  /** How far to scale down while pressed. */
  scaleTo?: number;
}

/**
 * The single tappable primitive. Springs down a touch on press and back on
 * release, with an optional soft haptic — so every interaction feels physical
 * without any of it feeling loud.
 */
export function PressableScale({
  children,
  onPress,
  disabled,
  haptic = true,
  style,
  scaleTo = motion.pressScale,
}: PressableScaleProps) {
  const scale = useRef(new Animated.Value(1)).current;

  const spring = (to: number) =>
    Animated.spring(scale, {
      toValue: to,
      useNativeDriver: true,
      damping: motion.spring.damping,
      stiffness: motion.spring.stiffness,
      mass: motion.spring.mass,
    }).start();

  return (
    <Pressable
      disabled={disabled}
      onPressIn={() => {
        spring(scaleTo);
        if (haptic) tapLight();
      }}
      onPressOut={() => spring(1)}
      onPress={onPress}
    >
      <Animated.View style={[{ transform: [{ scale }] }, style]}>{children}</Animated.View>
    </Pressable>
  );
}
