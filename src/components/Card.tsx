import type { ReactNode } from 'react';
import { View, type ViewStyle } from 'react-native';
import { radius, space, useColors, useIsDark } from '@/theme';

interface CardProps {
  children: ReactNode;
  /** Soft green wash for the "this is your invitation" hero card. */
  emphasis?: boolean;
  style?: ViewStyle;
}

export function Card({ children, emphasis, style }: CardProps) {
  const c = useColors();
  const isDark = useIsDark();

  return (
    <View
      style={[
        {
          backgroundColor: emphasis ? c.brandWash : c.surface,
          borderRadius: radius.xl,
          borderWidth: 1,
          borderColor: emphasis ? 'transparent' : c.border,
          padding: space.xl,
          // A soft, low, diffuse shadow — depth without weight. Muted in dark.
          shadowColor: '#1E2419',
          shadowOpacity: isDark ? 0.28 : 0.07,
          shadowRadius: 18,
          shadowOffset: { width: 0, height: 8 },
          elevation: 2,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}
