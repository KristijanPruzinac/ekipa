import { ActivityIndicator, View, type ViewStyle } from 'react-native';
import { confirm } from '@/lib/haptics';
import { radius, space, useColors } from '@/theme';
import { PressableScale } from './PressableScale';
import { Text } from './Text';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';

interface ButtonProps {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  loading?: boolean;
  disabled?: boolean;
  /** Success haptic on press — reserve for real commitments (e.g. "Yes, I'll come"). */
  celebrate?: boolean;
  style?: ViewStyle;
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  loading,
  disabled,
  celebrate,
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
    <PressableScale
      onPress={() => {
        if (celebrate) confirm();
        onPress?.();
      }}
      disabled={isDisabled}
      haptic={!celebrate}
      style={style}
    >
      <View
        style={{
          minHeight: 56,
          borderRadius: radius.lg,
          paddingHorizontal: space.xl,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: bg[variant],
          borderWidth: variant === 'ghost' ? 0 : 1.5,
          borderColor: border[variant],
          opacity: isDisabled ? 0.5 : 1,
        }}
      >
        {loading ? (
          <ActivityIndicator color={variant === 'primary' ? c.textOnBrand : c.brand} />
        ) : (
          <Text variant="bodyStrong" tone={tone}>
            {label}
          </Text>
        )}
      </View>
    </PressableScale>
  );
}
