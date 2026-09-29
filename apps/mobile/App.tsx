import { StatusBar } from "expo-status-bar"
import { StyleSheet, Text, View } from "react-native"
import { colors, space } from "./src/theme"

// Placeholder. A tela VIDA (timeline) substitui isto na Fase 1 (bíblia §49).
export default function App() {
  return (
    <View style={styles.root}>
      <Text style={styles.wordmark}>PARALELO</Text>
      <View style={styles.rule} />
      <Text style={styles.body}>Estrutura pronta. Nada foi simulado ainda.</Text>
      <StatusBar style="light" />
    </View>
  )
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg,
    paddingHorizontal: space[4],
    justifyContent: "center",
  },
  wordmark: { color: colors.text, fontSize: 32, fontWeight: "700", letterSpacing: 2 },
  rule: { height: 1, backgroundColor: colors.rule, marginVertical: space[4] },
  body: { color: colors.textSecondary, fontSize: 16 },
})
