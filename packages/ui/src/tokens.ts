// Design tokens iniciais (bíblia §58). Ponto de partida, não matemática rígida.
export const colors = {
  bg: "#111315",
  surface: "#181B1E",
  surfaceRaised: "#202428",
  rule: "#30353A",
  text: "#EEECE6",
  textSecondary: "#A5A49F",
  textMuted: "#747670",
  accent: "#B8E986",
  warning: "#E6B95C",
  danger: "#D86A62",
  info: "#7DA7D9",
} as const

export const space = {
  1: 4,
  2: 8,
  3: 12,
  4: 16,
  6: 24,
  8: 32,
  12: 48,
} as const

export const radius = {
  none: 0,
  sm: 4,
  md: 8,
  lg: 12,
} as const
