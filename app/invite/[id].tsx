import { router, useLocalSearchParams } from 'expo-router';
import { View } from 'react-native';
import { Button, Card, Screen, Text } from '@/components';
import { endTimeLabel, formatDuration, formatWhen } from '@/lib/format';
import { MOCK_MEETUP, MOCK_STANDING } from '@/lib/mock';
import { radius, space, useColors } from '@/theme';

export default function InviteDetail() {
  const c = useColors();
  const { id } = useLocalSearchParams<{ id: string }>();
  const meetup = id === MOCK_STANDING.id ? MOCK_STANDING : MOCK_MEETUP;

  return (
    <Screen
      footer={
        <View style={{ gap: space.sm }}>
          <Button label="Yes, I'll come" onPress={() => router.replace('/reflect/preview')} />
          <Button
            label="Not this time"
            variant="ghost"
            onPress={() => router.back()}
          />
          <Text variant="caption" tone="muted" center>
            Saying no is completely private. No one is told, and it won't affect future invitations.
          </Text>
        </View>
      }
    >
      <View style={{ alignItems: 'center', gap: space.md, marginBottom: space.xl }}>
        <View
          style={{
            width: 72,
            height: 72,
            borderRadius: radius.lg,
            backgroundColor: c.brandWash,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Text style={{ fontSize: 36 }}>{meetup.emoji}</Text>
        </View>
        <Text variant="title" center>
          {meetup.activityLabel}
        </Text>
        <Text variant="body" tone="soft" center>
          {formatWhen(meetup.startsAt)} – {endTimeLabel(meetup.startsAt, meetup.durationMin)}
          {'  ·  '}
          {formatDuration(meetup.durationMin)}
        </Text>
      </View>

      <Card>
        <Text variant="label" tone="muted">
          WHERE
        </Text>
        <Text variant="bodyStrong" style={{ marginTop: space.xs }}>
          {meetup.venueName}
        </Text>
        <Text variant="callout" tone="soft" style={{ marginTop: 2 }}>
          {meetup.venueNote} · Public place.
        </Text>
      </Card>

      <View style={{ height: space.md }} />

      <Card>
        <Text variant="label" tone="muted">
          WHAT TO EXPECT
        </Text>
        <Text variant="body" tone="soft" style={{ marginTop: space.sm }}>
          {meetup.whatToExpect}
        </Text>
      </Card>

      <View style={{ height: space.md }} />

      <Card>
        <Text variant="label" tone="muted">
          WHO'S COMING
        </Text>
        <View style={{ gap: space.lg, marginTop: space.md }}>
          {meetup.attendees.map((a) => (
            <View key={a.id} style={{ flexDirection: 'row', gap: space.md }}>
              <View
                style={{
                  width: 40,
                  height: 40,
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
            </View>
          ))}
        </View>
      </Card>
    </Screen>
  );
}
