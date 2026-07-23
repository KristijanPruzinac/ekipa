import { ActivityIndicator, Pressable, type ViewStyle } from 'react-native';
import { radius, space, useColors } from '@/theme';
import { Text } from './Text';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';

interface ButtonProps {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  loading,
  disabled,
  style,
}: ButtonProps) {
  const c = useColors();
  const isDisabled = disabled || loading;

  const bg: Record<Variant, string> = {
    primary: c.brand,
    secondary: c.surface,
    ghost: 'transparent',
    danger: c.surface,
  };
  const border: Record<Variant, string> = {
    primary: c.brand,
    secondary: c.border,
    ghost: 'transparent',
    danger: c.danger,
  };
  const tone = variant === 'primary' ? 'onBrand' : variant === 'danger' ? 'danger' : 'default';

  return (
    <Pressable
      onPress={onPress}
      disabled={isDisabled}
      style={({ pressed }) => [
        {
          minHeight: 56,
          borderRadius: radius.lg,
          paddingHorizontal: space.xl,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: bg[variant],
          borderWidth: variant === 'ghost' ? 0 : 1.5,
          borderColor: border[variant],
          opacity: isDisabled ? 0.5 : pressed ? 0.85 : 1,
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={variant === 'primary' ? c.textOnBrand : c.brand} />
      ) : (
        <Text variant="bodyStrong" tone={tone}>
          {label}
        </Text>
      )}
    </Pressable>
  );
}
