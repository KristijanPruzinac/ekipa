import { Pressable, View } from 'react-native';
import { radius, space, useColors } from '@/theme';
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
  const Container: typeof Pressable | typeof View = onPress ? Pressable : View;

  return (
    <Container
      onPress={onPress}
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
      <Text variant="callout" tone={selected ? 'brand' : 'soft'} style={{ fontWeight: '600' }}>
        {label}
      </Text>
    </Container>
  );
}
