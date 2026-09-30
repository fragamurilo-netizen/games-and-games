// CORPO na Vida (bíblia §21, §3, §7.3): o espelho em frases, poucas ações que cabem no momento
// e a roupa do dia. Guarda-roupa e loja ficam recolhidos para não virar lista gigante.
import { useMemo, useState } from "react"
import { Pressable, StyleSheet, Text, View } from "react-native"
import { queryBody } from "@paralelo/simulation"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"
import { ActionRow, Kicker, ui } from "./editorial"

export function BodySection() {
  const { world } = useGame()
  const body = useMemo(() => world ? queryBody(world) : null, [world])
  const [open, setOpen] = useState<"closed" | "wardrobe" | "shop">("closed")
  if (!body) return null
  const toggle = (next: "wardrobe" | "shop") => setOpen(open === next ? "closed" : next)
  return <>
    <Kicker meta={body.weight}>Corpo</Kicker>
    {body.lines.map(line => <Text key={line} style={styles.line}>{line}</Text>)}
    {body.trend && <Text style={styles.trend}>{body.trend}</Text>}
    <View style={styles.rows}>
      {[...body.actions, ...body.care].map(item => <ActionRow key={item.key} label={item.label} meta={item.meta}
        disabled={!item.canDo} reason={item.reason} command={item.command} />)}
    </View>

    <Kicker meta={body.wardrobe.hint ?? undefined}>Roupa de hoje</Kicker>
    <Text style={styles.wearing}>{body.wardrobe.wearing}</Text>
    <View style={styles.links}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: open === "wardrobe" }} onPress={() => toggle("wardrobe")} style={styles.link}>
        <Text style={styles.linkText}>{open === "wardrobe" ? "Fechar o guarda-roupa" : "Trocar de roupa"}</Text>
      </Pressable>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: open === "shop" }} onPress={() => toggle("shop")} style={styles.link}>
        <Text style={styles.linkText}>{open === "shop" ? "Sair da loja" : "Comprar roupa"}</Text>
      </Pressable>
    </View>
    {open === "wardrobe" && body.wardrobe.owned.map(item => <ActionRow key={item.id} label={item.label} meta={item.wearing ? "vestindo" : undefined}
      disabled={item.wearing} command={{ type: "dress", outfit: item.id }} />)}
    {open === "shop" && <>
      <Text style={ui.reason}>Loja do centro, das 9h às 20h. Você sai vestindo o que comprar.</Text>
      {body.wardrobe.shop.map(item => <ActionRow key={item.id} label={item.label} meta={item.price}
        disabled={!item.canBuy} reason={item.reason} command={{ type: "buy-clothes", outfit: item.id }} />)}
    </>}
  </>
}

const styles = StyleSheet.create({
  line: { color: colors.text, fontFamily: fonts.narrative, fontSize: 17, lineHeight: 25, marginTop: space[1] },
  trend: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, lineHeight: 21, marginTop: space[2] },
  rows: { marginTop: space[3] },
  wearing: { color: colors.text, fontFamily: fonts.medium, fontSize: 16, lineHeight: 23 },
  links: { flexDirection: "row", gap: space[6], marginTop: space[1] },
  link: { paddingVertical: space[3] },
  linkText: { color: colors.textSecondary, fontFamily: fonts.medium, fontSize: 14 },
})
