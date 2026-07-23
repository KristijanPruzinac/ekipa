import { router } from 'expo-router';
import { View } from 'react-native';
import { Appear, Card, PressableScale, Screen, Text } from '@/components';
import { formatDuration, formatWhen } from '@/lib/format';
import { MOCK_MEETUP, MOCK_STANDING } from '@/lib/mock';
import type { Meetup } from '@/lib/types';
import { radius, space, useColors } from '@/theme';

export default function Home() {
  return (
    <Screen>
      <Appear>
        <View style={{ gap: space.xs, marginBottom: space.xl }}>
          <Text variant="label" tone="brand">
            OSIJEK
          </Text>
          <Text variant="title">A new invitation</Text>
        </View>
      </Appear>

      <Appear delay={80}>
        <InviteCard meetup={MOCK_MEETUP} hero />
      </Appear>

      <View style={{ height: space.xxl }} />

      <Appear delay={160}>
        <Text variant="label" tone="muted" style={{ marginBottom: space.md }}>
          YOUR STANDING GROUP
        </Text>
        <InviteCard meetup={MOCK_STANDING} />
      </Appear>
    </Screen>
  );
}

function InviteCard({ meetup, hero }: { meetup: Meetup; hero?: boolean }) {
  const c = useColors();
  const names = meetup.attendees.map((a) => a.firstName).join(', ');

  return (
    <PressableScale onPress={() => router.push(`/invite/${meetup.id}`)}>
      <Card emphasis={hero}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: space.md }}>
          <View
            style={{
              width: 52,
              height: 52,
              borderRadius: radius.md,
              backgroundColor: hero ? c.surface : c.brandWash,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Text style={{ fontSize: 26 }}>{meetup.emoji}</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text variant="heading">{meetup.activityLabel}</Text>
            <Text variant="callout" tone="soft">
              {meetup.venueName}
            </Text>
          </View>
        </View>

        <View style={{ height: 1, backgroundColor: c.border, marginVertical: space.lg }} />

        <Row label="When" value={formatWhen(meetup.startsAt)} />
        <Row label="For" value={formatDuration(meetup.durationMin)} />
        <Row label="With" value={names} />

        <View style={{ marginTop: space.lg }}>
          <Text variant="calloutStrong" tone={hero ? 'brand' : 'muted'}>
            {meetup.status === 'confirmed' ? 'Confirmed · every other week →' : 'Tap to see the plan →'}
          </Text>
        </View>
      </Card>
    </PressableScale>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ flexDirection: 'row', gap: space.md, marginBottom: space.sm }}>
      <Text variant="callout" tone="muted" style={{ width: 48 }}>
        {label}
      </Text>
      <Text variant="callout" tone="soft" style={{ flex: 1 }}>
        {value}
      </Text>
    </View>
  );
}
