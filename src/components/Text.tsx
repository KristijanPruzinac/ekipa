import { Text as RNText, type TextProps as RNTextProps } from 'react-native';
import { type Colors, type TypeVariant, useColors, type as typeScale } from '@/theme';

type Tone = 'default' | 'soft' | 'muted' | 'brand' | 'accent' | 'onBrand' | 'danger';

export interface TextProps extends RNTextProps {
  variant?: TypeVariant;
  tone?: Tone;
  center?: boolean;
}

function toneColor(tone: Tone, c: Colors): string {
  switch (tone) {
    case 'soft':
      return c.textSoft;
    case 'muted':
      return c.textMuted;
    case 'brand':
      return c.brand;
    case 'accent':
      return c.accent;
    case 'onBrand':
      return c.textOnBrand;
    case 'danger':
      return c.danger;
    default:
      return c.text;
  }
}

export function Text({
  variant = 'body',
  tone = 'default',
  center,
  style,
  ...rest
}: TextProps) {
  const c = useColors();
  return (
    <RNText
      style={[
        typeScale[variant],
        { color: toneColor(tone, c) },
        center && { textAlign: 'center' },
        style,
      ]}
      {...rest}
    />
  );
}
