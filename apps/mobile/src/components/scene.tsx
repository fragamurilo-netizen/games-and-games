// Cena da Vida: o personagem de corpo inteiro no lugar e na hora em que está.
// Céu, sol/lua e janelas acesas vêm do relógio do jogo; a cidade vem do nome dela.
import { memo, useEffect, useMemo, useRef } from "react"
import { Animated, Easing, StyleSheet, Text, View } from "react-native"
import Svg, { Circle, Defs, Ellipse, LinearGradient, Rect, Stop } from "react-native-svg"
import { SvgXml } from "react-native-svg"
import { drawCharacter, type CharacterExpression, type CharacterSex } from "@paralelo/characters"
import { colors, fonts, space } from "../theme"

type Key = readonly [minute: number, top: string, bottom: string]
const SKY: readonly Key[] = [
  [0, "#0b1020", "#1a2135"], [300, "#101829", "#29273a"], [360, "#2b2d4a", "#c98a6b"], [450, "#5f82ab", "#e0c3a0"],
  [660, "#6a97c4", "#cddde2"], [960, "#7894b9", "#e2cfb2"], [1080, "#3d3a5c", "#cf7f5d"], [1200, "#151a2c", "#3a3452"], [1440, "#0b1020", "#1a2135"],
]
const hexToRgb = (h: string): number[] => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
const rgbToHex = (c: number[]): string => "#" + c.map(v => Math.round(v).toString(16).padStart(2, "0")).join("")
const mixHex = (a: string, b: string, t: number): string => { const x = hexToRgb(a), y = hexToRgb(b); return rgbToHex(x.map((v, i) => v + (y[i]! - v) * t)) }
export function skyAt(minute: number): { top: string; bottom: string; night: number } {
  let i = 0
  while (i < SKY.length - 2 && SKY[i + 1]![0] <= minute) i++
  const [m0, t0, b0] = SKY[i]!, [m1, t1, b1] = SKY[i + 1]!
  const t = (minute - m0) / Math.max(1, m1 - m0)
  const night = minute < 330 || minute > 1170 ? 1 : minute < 420 ? (420 - minute) / 90 : minute > 1110 ? (minute - 1110) / 60 : 0
  return { top: mixHex(t0, t1, t), bottom: mixHex(b0, b1, t), night: Math.min(1, night) }
}

const hash = (s: string): number => { let h = 2166136261; for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619); return h >>> 0 }

const Skyline = memo(function Skyline({ city, width, base, tone, night, far = false }: { city: string; width: number; base: number; tone: string; night: number; far?: boolean }) {
  const buildings = useMemo(() => {
    let h = hash(city)
    const next = () => { h = Math.imul(h ^ (h >>> 15), 2246822519) >>> 0; return h / 4294967296 }
    const out: { x: number; w: number; h: number; windows: { x: number; y: number }[] }[] = []
    for (let x = -10; x < width + 10;) {
      const tower = next() < 0.18
      const w = tower ? 16 + next() * 14 : 30 + next() * 46, bh = tower ? 80 + next() * 60 : 22 + next() * 58
      const windows: { x: number; y: number }[] = []
      for (let wy = 10; wy < bh - 12; wy += 14) for (let wx = 6; wx < w - 8; wx += 11) if (next() < 0.28) windows.push({ x: x + wx, y: base - bh + wy })
      out.push({ x, w, h: bh, windows })
      x += w + 2 + next() * 10
    }
    return out
  }, [city, width, base, far])
  return <>
    {buildings.map((b, i) => <Rect key={i} x={b.x} y={base - b.h} width={b.w} height={b.h} fill={tone} />)}
    {night > 0.05 && !far && buildings.flatMap((b, i) => b.windows.map((w, j) => <Rect key={`${i}-${j}`} x={w.x} y={w.y} width={4} height={6} fill="#e6b95c" opacity={0.75 * night} />))}
  </>
})

type Props = {
  width: number
  minute: number
  city: string
  seed: string
  sex: CharacterSex
  age: number
  expression: CharacterExpression
  children?: React.ReactNode
  /** altura da cena; por padrão quase quadrada */
  height?: number
}

export function LifeScene({ width, minute, city, seed, sex, age, expression, children, height: fixed }: Props) {
  const height = fixed ?? Math.round(width * 1.02)
  const ground = height - 34
  const sky = skyAt(minute)
  const body = useMemo(() => drawCharacter({ seed, sex, age, view: "body", background: false, expression }), [seed, sex, age, expression])
  const figureH = height * 0.76
  const figureW = figureH * (body.width / body.height)
  // sol de 6h a 18h, lua no resto
  const dayT = (minute - 360) / 720
  const isDay = dayT >= 0 && dayT <= 1
  const t = isDay ? dayT : ((minute + (minute < 360 ? 1440 : 0)) - 1080) / 720
  const cx = width * (0.62 + 0.3 * t), cy = height * 0.6 - Math.sin(Math.PI * t) * height * 0.2
  // entrada suave quando a cena monta ou a expressão muda
  const fade = useRef(new Animated.Value(0)).current
  useEffect(() => { fade.setValue(0.4); Animated.timing(fade, { toValue: 1, duration: 500, easing: Easing.out(Easing.quad), useNativeDriver: true }).start() }, [expression, fade])

  return <View style={{ width, height, overflow: "hidden" }}>
    <Svg width={width} height={height} style={StyleSheet.absoluteFill}>
      <Defs>
        <LinearGradient id="sky" x1="0" y1="0" x2="0" y2={ground} gradientUnits="userSpaceOnUse">
          <Stop offset="0" stopColor={sky.top} /><Stop offset="1" stopColor={sky.bottom} />
        </LinearGradient>
        <LinearGradient id="floor" x1="0" y1={ground} x2="0" y2={height} gradientUnits="userSpaceOnUse">
          <Stop offset="0" stopColor="#1c1f23" /><Stop offset="1" stopColor={colors.bg} />
        </LinearGradient>
        <LinearGradient id="scrim" x1="0" y1="0" x2="0" y2={height * 0.5} gradientUnits="userSpaceOnUse">
          <Stop offset="0" stopColor="#000" stopOpacity={0.5} /><Stop offset="1" stopColor="#000" stopOpacity={0} />
        </LinearGradient>
      </Defs>
      <Rect width={width} height={ground} fill="url(#sky)" />
      <Circle cx={cx} cy={cy} r={isDay ? 22 : 15} fill={isDay ? "#f6e3b4" : "#dfe3ea"} opacity={isDay ? 0.9 : 0.8} />
      <Skyline city={`${city}/longe`} width={width} base={ground - 18} tone={mixHex(sky.bottom, "#0d0f12", 0.3)} night={sky.night} far />
      <Skyline city={city} width={width} base={ground} tone={mixHex(sky.bottom, "#0d0f12", 0.62)} night={sky.night} />
      <Rect y={ground} width={width} height={height - ground} fill="url(#floor)" />
      <Ellipse cx={width / 2} cy={ground + 6} rx={figureW * 0.34} ry={7} fill="#000" opacity={0.35} />
      <Rect width={width} height={height * 0.5} fill="url(#scrim)" />
    </Svg>
    <Animated.View style={{ position: "absolute", left: (width - figureW) / 2, top: ground + 10 - figureH, opacity: fade }}>
      <SvgXml xml={body.svg} width={figureW} height={figureH} />
    </Animated.View>
    <View style={styles.overlay} pointerEvents="box-none">{children}</View>
  </View>
}

const styles = StyleSheet.create({
  overlay: { position: "absolute", top: 0, left: 0, right: 0, bottom: 0, paddingHorizontal: space[6], paddingTop: space[4] },
})
export const sceneText = StyleSheet.create({
  kicker: { color: "rgba(255,255,255,0.72)", fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6 },
  day: { color: "#fbf8f1", fontFamily: fonts.title, fontSize: 32, lineHeight: 38, marginTop: 2, textShadowColor: "rgba(0,0,0,0.35)", textShadowRadius: 8 },
  time: { color: "#fbf8f1", fontFamily: fonts.medium, fontSize: 30, fontVariant: ["tabular-nums"], textShadowColor: "rgba(0,0,0,0.35)", textShadowRadius: 8 },
})
