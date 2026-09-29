import { useMemo } from "react"
import { StyleSheet, Text, View } from "react-native"
import { queryCareer, queryLife } from "@paralelo/simulation"
import type { CourseId } from "@paralelo/shared"
import { ActionRow, FactRow, Kicker, Page, Prose } from "../components/editorial"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

// CARREIRA: fatos objetivos, avaliação em linguagem, oportunidades (bíblia §15, §61, §75).
export default function CareerScreen() {
  const { world } = useGame()
  const career = useMemo(() => world ? queryCareer(world) : null, [world])
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  if (!career || !life) return null
  const job = career.employment
  return <Page time={life.time}>
    {job ? <>
      <Text style={styles.company}>{job.company.toLocaleUpperCase("pt-BR")}</Text>
      <Text accessibilityRole="header" style={styles.title}>{job.title}</Text>
      <FactRow label="Salário" value={`${job.salary} / 20 turnos`} />
      <FactRow label="Desde" value={job.started} />
      <FactRow label="Turnos neste mês" value={String(job.shifts)} />
      <FactRow label="A receber" value={job.accrued} />
      <Kicker>Situação</Kicker>
      <Prose>{job.performance}</Prose>
      <Prose tone={job.warning ? "warning" : "secondary"}>{job.presence}</Prose>
      <View style={styles.actions}>
        <ActionRow label="Ir trabalhar" meta="8 h" disabled={!career.canWork} reason={career.unavailableReason} command={{ type: "work" }} />
        {career.nextWork.waitMinutes > 0 && <ActionRow label="Esperar o próximo turno" meta={`${career.nextWork.date.split(" de ").slice(0, 2).join(" de ")}, ${career.nextWork.time}`}
          command={{ type: "wait", minutes: career.nextWork.waitMinutes }} />}
      </View>
    </> : <>
      <Text style={styles.company}>SEM CONTRATO</Text>
      <Text accessibilityRole="header" style={styles.title}>Procurando trabalho</Text>
      <Prose tone="secondary">As vagas abaixo existem em empresas da cidade. Algumas pedem preparo que um curso pode dar.</Prose>
    </>}

    <Kicker meta={`${career.vacancies.length} abertas`}>Vagas</Kicker>
    {career.vacancies.map(v => <View key={v.id} style={styles.item}>
      <View style={styles.itemHead}>
        <Text style={styles.itemTitle}>{v.title}</Text>
        <Text style={styles.itemValue}>{v.salary}</Text>
      </View>
      <Text style={styles.itemSub}>{v.company} · pede {v.preparation.toLowerCase()}</Text>
      <ActionRow label="Enviar currículo" meta="30 min" disabled={!v.canApply} reason={v.reason} command={{ type: "apply-job", vacancyId: v.id }} />
    </View>)}

    <Kicker>Formação</Kicker>
    {career.courses.map(course => <View key={course.id} style={styles.item}>
      <View style={styles.itemHead}>
        <Text style={styles.itemTitle}>{course.title}</Text>
        <Text style={styles.itemValue}>{course.progress.replace(" aulas", "")}</Text>
      </View>
      <Text style={styles.itemSub}>{course.institution} · {course.price} por aula</Text>
      <ActionRow label="Assistir à aula" meta="2 h" disabled={!course.canStudy} reason={course.reason} command={{ type: "study", courseId: course.id as CourseId }} />
    </View>)}

    {!!career.history.length && <>
      <Kicker>Por onde passou</Kicker>
      {career.history.map(h => <View key={h.id} style={styles.item}>
        <View style={styles.itemHead}><Text style={styles.itemTitle}>{h.title}</Text><Text style={styles.itemValue}>{h.settlement}</Text></View>
        <Text style={styles.itemSub}>{h.company} · saída em {h.ended}</Text>
        <Text style={styles.itemSub}>{h.reason}</Text>
      </View>)}
    </>}
  </Page>
}

const styles = StyleSheet.create({
  company: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6, marginTop: space[6] },
  title: { color: colors.text, fontFamily: fonts.title, fontSize: 32, lineHeight: 38, marginTop: space[1], marginBottom: space[3] },
  actions: { marginTop: space[3] },
  item: { paddingTop: space[3] },
  itemHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", gap: space[4] },
  itemTitle: { flex: 1, color: colors.text, fontFamily: fonts.title, fontSize: 19, lineHeight: 24 },
  itemValue: { color: colors.text, fontFamily: fonts.medium, fontSize: 14, fontVariant: ["tabular-nums"] },
  itemSub: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: 2 },
})
