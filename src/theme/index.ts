import { useColorScheme } from 'react-native';
import { dark, light, type Colors } from './tokens';

export * from './tokens';

/** Resolve the active color set from the device appearance. */
export function useColors(): Colors {
  const scheme = useColorScheme();
  return scheme === 'dark' ? dark : light;
}

export function useIsDark(): boolean {
  return useColorScheme() === 'dark';
}
