import type { ReactNode } from 'react';
import { useEffect, useRef } from 'react';
import { Animated, type ViewStyle } from 'react-native';
import { motion } from '@/theme';

interface AppearProps {
  children: ReactNode;
  /** Stagger, in ms — pass index * ~70 for a gentle cascade. */
  delay?: number;
  style?: ViewStyle;
}

/**
 * Gentle fade-and-rise on mount. Used to let content settle in rather than
 * snap — the whole app should feel like it exhales, not flashes.
 */
export function Appear({ children, delay = 0, style }: AppearProps) {
  const progress = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(progress, {
      toValue: 1,
      duration: motion.duration.slow,
      delay,
      useNativeDriver: true,
    }).start();
  }, [progress, delay]);

  return (
    <Animated.View
      style={[
        {
          opacity: progress,
          transform: [
            {
              translateY: progress.interpolate({
                inputRange: [0, 1],
                outputRange: [10, 0],
              }),
            },
          ],
        },
        style,
      ]}
    >
      {children}
    </Animated.View>
  );
}
