import type { ReactNode } from 'react';
import { View, type ViewStyle } from 'react-native';
import { radius, space, useColors } from '@/theme';

interface CardProps {
  children: ReactNode;
  /** Soft green wash for the "this is your invitation" hero card. */
  emphasis?: boolean;
  style?: ViewStyle;
}

export function Card({ children, emphasis, style }: CardProps) {
  const c = useColors();
  return (
    <View
      style={[
        {
          backgroundColor: emphasis ? c.brandWash : c.surface,
          borderRadius: radius.xl,
          borderWidth: 1,
          borderColor: emphasis ? 'transparent' : c.border,
          padding: space.xl,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}
