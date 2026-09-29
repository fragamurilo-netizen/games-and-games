import { memo, useId, useMemo, useRef, useState } from "react"
import { PanResponder, View, type ViewStyle } from "react-native"
import Svg, { ClipPath, Defs, LinearGradient, Path, RadialGradient, Stop } from "react-native-svg"
import { createAppearance, type Sex } from "@paralelo/simulation"
import { buildPortrait, renderPortrait, type DisplayList } from "@paralelo/ui"

type Props = {
  seed: string
  sex: Sex
  age: number
  /** largura em pontos; a altura segue a proporção 4:5 */
  size: number
  /** arrastar para os lados gira a pessoa */
  rotatable?: boolean
  accessibilityLabel: string
  style?: ViewStyle
}

// Retrato vetorial em busto. O modelo é caro e só muda com pessoa e idade;
// girar apenas reprojeta o modelo no novo ângulo.
export const Portrait = memo(function Portrait({ seed, sex, age, size, rotatable = false, accessibilityLabel, style }: Props) {
  const model = useMemo(() => buildPortrait(createAppearance(seed, { sex }), { age }), [seed, sex, age])
  const [yaw, setYaw] = useState(0)
  const start = useRef(0)
  const frame = useRef<number | null>(null)
  const pending = useRef(0)
  const prefix = useId().replace(/[^a-zA-Z0-9]/g, "")
  const list = useMemo(() => renderPortrait(model, yaw, `r${prefix}`), [model, yaw, prefix])
  const pan = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder: (_, g) => rotatable && Math.abs(g.dx) > 6 && Math.abs(g.dx) > Math.abs(g.dy),
    onPanResponderGrant: () => { start.current = pending.current },
    onPanResponderMove: (_, g) => {
      pending.current = start.current + g.dx * 0.018
      if (frame.current === null) frame.current = requestAnimationFrame(() => { frame.current = null; setYaw(pending.current) })
    },
    onPanResponderTerminationRequest: () => false,
  }), [rotatable])
  return <View style={[{ width: size, height: size * 1.25 }, style]} accessible accessibilityRole="image"
    accessibilityLabel={accessibilityLabel} accessibilityHint={rotatable ? "Arraste para os lados para girar." : undefined} {...pan.panHandlers}>
    <DisplayListSvg list={list} width={size} />
  </View>
})

// Enquadramento do busto dentro do quadro 400 x 500 (mantém 4:5).
const CROP = { x: 30, y: 44, w: 340, h: 425 }

function DisplayListSvg({ list, width }: { list: DisplayList; width: number }) {
  return <Svg width={width} height={width * (CROP.h / CROP.w)} viewBox={`${CROP.x} ${CROP.y} ${CROP.w} ${CROP.h}`}>
    <Defs>
      {list.gradients.map(g => g.type === "linear"
        ? <LinearGradient key={g.id} id={g.id} gradientUnits="userSpaceOnUse" x1={g.x1} y1={g.y1} x2={g.x2} y2={g.y2}>
          {g.stops.map(([o, c, a], i) => <Stop key={i} offset={o} stopColor={c} stopOpacity={a} />)}
        </LinearGradient>
        : <RadialGradient key={g.id} id={g.id} gradientUnits="userSpaceOnUse" cx={0} cy={0} r={1} gradientTransform={g.transform}>
          {g.stops.map(([o, c, a], i) => <Stop key={i} offset={o} stopColor={c} stopOpacity={a} />)}
        </RadialGradient>)}
      {list.clips.map(c => <ClipPath key={c.id} id={c.id}><Path d={c.d} /></ClipPath>)}
    </Defs>
    {list.items.map((it, i) => <Path key={i} d={it.d} fill={it.fill ?? "none"} stroke={it.stroke} strokeWidth={it.width}
      strokeLinecap={it.cap} strokeLinejoin={it.join} opacity={it.opacity} clipPath={it.clip ? `url(#${it.clip})` : undefined}
      fillRule={it.evenOdd ? "evenodd" : undefined} />)}
  </Svg>
}
