/**
 * Ekipa design tokens.
 *
 * The brand is the opposite of a nightclub: quiet, natural, warm, unhurried.
 * Warm paper backgrounds, deep forest ink, a living green, a soft terracotta
 * accent used sparingly. Generous spacing and large, soft shapes so every
 * tap target feels calm and unambiguous — the whole product is designed to
 * lower social fear, and the surface should feel the same way.
 */

const palette = {
  // Warm paper neutrals (light)
  paper: '#F5F1E8',
  paperRaised: '#FBF8F1',
  paperSunken: '#EDE7DA',

  // Deep natural ink (light text)
  ink: '#23271F',
  inkSoft: '#4C5347',
  inkMuted: '#8A8F82',

  // Living green — the brand
  moss: '#4A6B4D',
  mossSoft: '#6E9070',
  mossWash: '#E4EBDF',

  // Soft terracotta — accent, used sparingly
  clay: '#C97B5A',
  claySoft: '#E0A88F',
  clayWash: '#F3E3DA',

  // Signal colors, muted to fit the palette
  gentleGreen: '#5B8C5A',
  gentleAmber: '#C79A3E',
  gentleRed: '#B25B4E',

  // Dark surfaces — deep forest at night
  night: '#161A14',
  nightRaised: '#1F241C',
  nightSunken: '#101410',

  // Dark text
  linen: '#ECE7DA',
  linenSoft: '#B7BAAC',
  linenMuted: '#7C8074',

  white: '#FFFFFF',
  black: '#000000',
} as const;

export interface Colors {
  bg: string;
  surface: string;
  surfaceSunken: string;
  border: string;
  text: string;
  textSoft: string;
  textMuted: string;
  textOnBrand: string;
  brand: string;
  brandSoft: string;
  brandWash: string;
  accent: string;
  accentSoft: string;
  accentWash: string;
  success: string;
  warning: string;
  danger: string;
}

export const light: Colors = {
  bg: palette.paper,
  surface: palette.paperRaised,
  surfaceSunken: palette.paperSunken,
  border: '#DED7C6',

  text: palette.ink,
  textSoft: palette.inkSoft,
  textMuted: palette.inkMuted,
  textOnBrand: palette.paperRaised,

  brand: palette.moss,
  brandSoft: palette.mossSoft,
  brandWash: palette.mossWash,

  accent: palette.clay,
  accentSoft: palette.claySoft,
  accentWash: palette.clayWash,

  success: palette.gentleGreen,
  warning: palette.gentleAmber,
  danger: palette.gentleRed,
};

export const dark: Colors = {
  bg: palette.night,
  surface: palette.nightRaised,
  surfaceSunken: palette.nightSunken,
  border: '#2E342A',

  text: palette.linen,
  textSoft: palette.linenSoft,
  textMuted: palette.linenMuted,
  textOnBrand: palette.night,

  brand: palette.mossSoft,
  brandSoft: palette.moss,
  brandWash: '#243021',

  accent: palette.claySoft,
  accentSoft: palette.clay,
  accentWash: '#332420',

  success: '#7FB27C',
  warning: '#D8B25E',
  danger: '#D07C6E',
};

/** 4pt spacing scale — generous by default. */
export const space = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
  xxxl: 48,
} as const;

export const radius = {
  sm: 10,
  md: 16,
  lg: 22,
  xl: 28,
  pill: 999,
} as const;

/**
 * Font families. Fraunces — a soft, natural serif — carries the wordmark and
 * titles for editorial warmth; Inter carries everything functional. Weight is
 * baked into the family name (never set fontWeight alongside a custom font, or
 * Android renders a faux-bold on top).
 */
export const fonts = {
  displayBold: 'Fraunces_700Bold',
  display: 'Fraunces_600SemiBold',
  strong: 'Inter_600SemiBold',
  medium: 'Inter_500Medium',
  regular: 'Inter_400Regular',
} as const;

export const type = {
  display: { fontFamily: fonts.displayBold, fontSize: 34, lineHeight: 40, letterSpacing: -0.5 },
  title: { fontFamily: fonts.display, fontSize: 26, lineHeight: 32, letterSpacing: -0.3 },
  heading: { fontFamily: fonts.strong, fontSize: 20, lineHeight: 27 },
  body: { fontFamily: fonts.regular, fontSize: 17, lineHeight: 26 },
  bodyStrong: { fontFamily: fonts.strong, fontSize: 17, lineHeight: 26 },
  callout: { fontFamily: fonts.regular, fontSize: 15, lineHeight: 22 },
  calloutStrong: { fontFamily: fonts.strong, fontSize: 15, lineHeight: 22 },
  label: { fontFamily: fonts.strong, fontSize: 13, lineHeight: 18, letterSpacing: 0.6 },
  caption: { fontFamily: fonts.regular, fontSize: 13, lineHeight: 18 },
} as const;

export type TypeVariant = keyof typeof type;

/** Motion tokens — everything gentle. Springs are soft, never bouncy. */
export const motion = {
  duration: { fast: 140, base: 240, slow: 380 },
  spring: { damping: 16, stiffness: 180, mass: 0.9 },
  pressScale: 0.97,
} as const;
