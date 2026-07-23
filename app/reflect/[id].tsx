import { router } from 'expo-router';
import { useRef, useState } from 'react';
import { Animated, Pressable, View } from 'react-native';
import { Appear, Button, Screen, Text } from '@/components';
import { tapSelect } from '@/lib/haptics';
import { MOCK_MEETUP } from '@/lib/mock';
import type { Attendee } from '@/lib/types';
import { motion, radius, space, useColors } from '@/theme';

export default function Reflect() {
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
      <Appear>
        <View style={{ gap: space.sm, marginBottom: space.xl }}>
          <Text variant="label" tone="brand">
            AFTER THE WALK
          </Text>
          <Text variant="title">Who would you be happy to see again?</Text>
          <Text variant="body" tone="soft">
            No rush and no rating — just a quiet nudge about who you'd enjoy running into next time.
          </Text>
        </View>
      </Appear>

      <View style={{ gap: space.md }}>
        {attendees.map((a, i) => (
          <Appear key={a.id} delay={100 + i * 70}>
            <AttendeeRow attendee={a} on={picked.has(a.id)} onToggle={() => toggle(a.id)} />
          </Appear>
        ))}
      </View>
    </Screen>
  );
}

function AttendeeRow({
  attendee,
  on,
  onToggle,
}: {
  attendee: Attendee;
  on: boolean;
  onToggle: () => void;
}) {
  const c = useColors();
  const heartScale = useRef(new Animated.Value(1)).current;

  function handle() {
    tapSelect();
    // A little pop as the heart fills, then settle.
    Animated.sequence([
      Animated.timing(heartScale, {
        toValue: 1.35,
        duration: motion.duration.fast,
        useNativeDriver: true,
      }),
      Animated.spring(heartScale, {
        toValue: 1,
        useNativeDriver: true,
        damping: 10,
        stiffness: 200,
        mass: 0.8,
      }),
    ]).start();
    onToggle();
  }

  return (
    <Pressable
      onPress={handle}
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
          {attendee.firstName[0]}
        </Text>
      </View>
      <View style={{ flex: 1 }}>
        <Text variant="bodyStrong">{attendee.firstName}</Text>
        <Text variant="callout" tone="muted">
          {attendee.blurb}
        </Text>
      </View>
      <Animated.Text
        style={{
          fontSize: 22,
          color: on ? c.brand : c.textMuted,
          transform: [{ scale: heartScale }],
        }}
      >
        {on ? '♥' : '♡'}
      </Animated.Text>
    </Pressable>
  );
}
