import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { Button, Screen, Text } from '@/components';
import { MOCK_MEETUP } from '@/lib/mock';
import { radius, space, useColors } from '@/theme';

export default function Reflect() {
  const c = useColors();
  const attendees = MOCK_MEETUP.attendees;
  const [picked, setPicked] = useState<Set<string>>(new Set());

  function toggle(id: string) {
    setPicked((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  return (
    <Screen
      footer={
        <View style={{ gap: space.sm }}>
          <Button label="Done" onPress={() => router.replace('/home')} />
          <Text variant="caption" tone="muted" center>
            Only shared when it's mutual. If they're not sure, no one ever finds out either way.
          </Text>
        </View>
      }
    >
      <View style={{ gap: space.sm, marginBottom: space.xl }}>
        <Text variant="label" tone="brand">
          AFTER THE WALK
        </Text>
        <Text variant="title">Who would you be happy to see again?</Text>
        <Text variant="body" tone="soft">
          No rush and no rating — just a quiet nudge about who you'd enjoy running into next time.
        </Text>
      </View>

      <View style={{ gap: space.md }}>
        {attendees.map((a) => {
          const on = picked.has(a.id);
          return (
            <Pressable
              key={a.id}
              onPress={() => toggle(a.id)}
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                gap: space.md,
                padding: space.lg,
                borderRadius: radius.lg,
                borderWidth: 1.5,
                borderColor: on ? c.brand : c.border,
                backgroundColor: on ? c.brandWash : c.surface,
              }}
            >
              <View
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: radius.pill,
                  backgroundColor: c.surfaceSunken,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Text variant="bodyStrong" tone="soft">
                  {a.firstName[0]}
                </Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text variant="bodyStrong">{a.firstName}</Text>
                <Text variant="callout" tone="muted">
                  {a.blurb}
                </Text>
              </View>
              <Text variant="heading" tone={on ? 'brand' : 'muted'}>
                {on ? '♥' : '♡'}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </Screen>
  );
}
