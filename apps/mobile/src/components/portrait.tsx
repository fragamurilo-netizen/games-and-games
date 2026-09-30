import { memo, useMemo } from "react"
import { View, type ViewStyle } from "react-native"
import { SvgXml } from "react-native-svg"
import { drawCharacter, type CharacterExpression, type CharacterLook, type CharacterSex } from "@paralelo/characters"

type Props = {
  seed: string
  sex: CharacterSex
  age: number
  /** largura em pontos; a altura segue a proporção do desenho */
  size: number
  accessibilityLabel: string
  /** fundo creme do laboratório; nas telas escuras o personagem fica solto */
  background?: boolean
  expression?: CharacterExpression
  /** corpo, roupa e barba de hoje, vindos da simulação */
  look?: CharacterLook
  style?: ViewStyle
}

// Retrato do personagem. O desenho vem do genoma (seed + sexo), da idade e de como a pessoa está hoje.
export const Portrait = memo(function Portrait({ seed, sex, age, size, accessibilityLabel, background = false, expression = "warm", look, style }: Props) {
  const lookKey = JSON.stringify(look ?? {})
  const drawing = useMemo(() => drawCharacter({ seed, sex, age, background, expression, look }), [seed, sex, age, background, expression, lookKey]) // eslint-disable-line react-hooks/exhaustive-deps
  const height = size * (drawing.height / drawing.width)
  return <View style={[{ width: size, height }, style]} accessible accessibilityRole="image" accessibilityLabel={accessibilityLabel}>
    <SvgXml xml={drawing.svg} width={size} height={height} />
  </View>
})
