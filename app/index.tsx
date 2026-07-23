import { router } from 'expo-router';
import { View } from 'react-native';
import { Appear, Button, Screen, Text } from '@/components';
import { space, useColors } from '@/theme';

export default function Welcome() {
  const c = useColors();

  return (
    <Screen
      scroll={false}
      footer={
        <View style={{ gap: space.sm }}>
          <Button label="Begin" onPress={() => router.push('/onboarding/activities')} />
          <Button
            label="I already have an account"
            variant="ghost"
            onPress={() => router.push('/home')}
          />
        </View>
      }
    >
      <View style={{ flex: 1, justifyContent: 'center', gap: space.xl }}>
        <View
          style={{
            width: 64,
            height: 64,
            borderRadius: 20,
            backgroundColor: c.brandWash,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Text style={{ fontSize: 30 }}>🌿</Text>
        </View>

        <Appear delay={80} style={{ gap: space.md }}>
          <Text variant="display">Ekipa</Text>
          <Text variant="heading" tone="soft">
            Company, without the noise.
          </Text>
        </Appear>

        <Appear delay={220} style={{ gap: space.md }}>
          <Bullet text="No texting anyone. No organizing anything." />
          <Bullet text="Small groups — never more than a few people." />
          <Bullet text="We plan it. You just say yes or no." />
        </Appear>
      </View>
    </Screen>
  );
}

function Bullet({ text }: { text: string }) {
  const c = useColors();
  return (
    <View style={{ flexDirection: 'row', gap: space.md, alignItems: 'center' }}>
      <View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: c.brand }} />
      <Text variant="body" tone="soft" style={{ flex: 1 }}>
        {text}
      </Text>
    </View>
  );
}
