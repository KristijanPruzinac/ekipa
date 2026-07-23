import { View } from 'react-native';
import { tapSelect } from '@/lib/haptics';
import { radius, space, useColors } from '@/theme';
import { PressableScale } from './PressableScale';
import { Text } from './Text';

interface TagProps {
  label: string;
  /** Selectable chip for tap-only onboarding. */
  selected?: boolean;
  onPress?: () => void;
  emoji?: string;
}

export function Tag({ label, selected, onPress, emoji }: TagProps) {
  const c = useColors();

  const inner = (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: space.xs,
        paddingVertical: space.sm + 2,
        paddingHorizontal: space.lg,
        borderRadius: radius.pill,
        borderWidth: 1.5,
        borderColor: selected ? c.brand : c.border,
        backgroundColor: selected ? c.brandWash : c.surface,
      }}
    >
      {emoji ? <Text variant="callout">{emoji}</Text> : null}
      <Text variant="calloutStrong" tone={selected ? 'brand' : 'soft'}>
        {label}
      </Text>
    </View>
  );

  if (!onPress) return inner;

  return (
    <PressableScale
      haptic={false}
      onPress={() => {
        tapSelect();
        onPress();
      }}
    >
      {inner}
    </PressableScale>
  );
}
