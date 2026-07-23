import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { Button, Screen, Tag, Text } from '@/components';
import { ACTIVITIES } from '@/lib/activities';
import { space } from '@/theme';

const MIN_PICKS = 3;

export default function OnboardingActivities() {
  const [selected, setSelected] = useState<Set<string>>(new Set());

  function toggle(slug: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      next.has(slug) ? next.delete(slug) : next.add(slug);
      return next;
    });
  }

  const enough = selected.size >= MIN_PICKS;
  const remaining = MIN_PICKS - selected.size;

  return (
    <Screen
      footer={
        <Button
          label={enough ? 'Continue' : `Pick ${remaining} more`}
          disabled={!enough}
          onPress={() => router.push('/home')}
        />
      }
    >
      <View style={{ gap: space.sm, marginBottom: space.xl }}>
        <Text variant="label" tone="brand">
          STEP 1 OF 3
        </Text>
        <Text variant="title">What would you enjoy?</Text>
        <Text variant="body" tone="soft">
          Things you do side by side, so there's never pressure to fill the silence. Pick a few —
          you can change these anytime.
        </Text>
      </View>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: space.sm }}>
        {ACTIVITIES.map((a) => (
          <Tag
            key={a.slug}
            label={a.label}
            emoji={a.emoji}
            selected={selected.has(a.slug)}
            onPress={() => toggle(a.slug)}
          />
        ))}
      </View>
    </Screen>
  );
}
