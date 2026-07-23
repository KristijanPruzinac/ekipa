import type { ReactNode } from 'react';
import { ScrollView, View, type ViewStyle } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { space, useColors } from '@/theme';

interface ScreenProps {
  children: ReactNode;
  /** Scrollable body (default) or a fixed full-height layout. */
  scroll?: boolean;
  /** Content pinned to the bottom (e.g. a primary action). */
  footer?: ReactNode;
  contentStyle?: ViewStyle;
}

/**
 * The single page frame for the whole app. Safe-area aware, calm padding,
 * optional pinned footer for the one primary action a screen should offer.
 */
export function Screen({ children, scroll = true, footer, contentStyle }: ScreenProps) {
  const c = useColors();
  const padding: ViewStyle = {
    paddingHorizontal: space.xl,
    paddingTop: space.xl,
    paddingBottom: space.xl,
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.bg }} edges={['top', 'bottom']}>
      {scroll ? (
        <ScrollView
          contentContainerStyle={[padding, { flexGrow: 1 }, contentStyle]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {children}
        </ScrollView>
      ) : (
        <View style={[padding, { flex: 1 }, contentStyle]}>{children}</View>
      )}
      {footer ? (
        <View
          style={{
            paddingHorizontal: space.xl,
            paddingTop: space.md,
            paddingBottom: space.lg,
            backgroundColor: c.bg,
            borderTopWidth: 1,
            borderTopColor: c.border,
          }}
        >
          {footer}
        </View>
      ) : null}
    </SafeAreaView>
  );
}
