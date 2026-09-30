import { useMemo } from "react"
import { StyleSheet, Text, View } from "react-native"
import { queryCareer, queryLife } from "@paralelo/simulation"
import type { CourseId, InterviewId } from "@paralelo/shared"
import { ActionRow, FactRow, Kicker, Page, Prose, TimeRow } from "../components/editorial"
import { Portrait } from "../components/portrait"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

const shortDate = (date: string): string => date.split(" de ").slice(0, 2).map((p, i) => (i ? p.slice(0, 3) : p)).join(" ")

// CARREIRA (bíblia §15, §61, §75): empresa, função, quem responde pela equipe, a situação em
// palavras, os próximos dias e as oportunidades reais.
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
      <FactRow label="Salário" value={`${job.salary} / mês`} />
      <FactRow label="Rotina" value={job.schedule} tone="muted" />
      <FactRow label="Tempo de casa" value={job.tenure} />
      <FactRow label="A receber no dia 1º" value={`${job.accrued} · ${job.shifts} ${job.shifts === 1 ? "turno" : "turnos"}`} />

      <Kicker>Situação</Kicker>
      {job.situation.map((line, i) => <Prose key={i} tone={/advertência|falta|caiu|corte|fraco/.test(line) ? "warning" : i === 0 ? "primary" : "secondary"}>{line}</Prose>)}

      <View style={styles.manager}>
        <Portrait seed={job.manager.appearance.seed} sex={job.manager.appearance.sex} age={job.manager.age} size={72} accessibilityLabel={`Retrato de ${job.manager.name}`} />
        <View style={styles.managerText}>
          <Text style={styles.managerName}>{job.manager.name}</Text>
          <Text style={styles.managerRole}>Responde pela equipe</Text>
          <Text style={styles.managerRelation}>{job.manager.relation}</Text>
        </View>
      </View>

      <View style={styles.actions}>
        <ActionRow label="Ir trabalhar" meta="8 h" disabled={!career.canWork} reason={career.unavailableReason} command={{ type: "work" }} />
        {!career.canWork && career.nextWork.waitMinutes > 0 && <ActionRow label="Esperar o próximo turno" meta={`${shortDate(career.nextWork.date)}, ${career.nextWork.time}`}
          command={{ type: "wait", minutes: career.nextWork.waitMinutes }} />}
      </View>
    </> : <>
      <Text style={styles.company}>SEM CONTRATO</Text>
      <Text accessibilityRole="header" style={styles.title}>Procurando trabalho</Text>
      <Prose tone="secondary">Mandar currículo marca uma entrevista. Quem se prepara, tem indicação ou já trabalhou na área chega com vantagem.</Prose>
    </>}

    {!!career.agenda.length && <>
      <Kicker>Próximos dias</Kicker>
      {career.agenda.map(item => <View key={item.id}>
        <TimeRow time={shortDate(item.date)}>
          <Text style={styles.agendaLabel}>{item.label}</Text>
          <Text style={styles.agendaTime}>{item.time}{item.prepare?.prepared ? " · preparado" : ""}</Text>
        </TimeRow>
        {item.prepare && !item.prepare.prepared && item.prepare.canPrepare && <ActionRow label={item.kind === "interview" ? "Preparar a entrevista" : "Preparar a conversa"} meta="1 h"
          disabled={!item.prepare.canPrepare} reason={item.prepare.reason}
          command={item.kind === "interview" ? { type: "prepare", target: "interview", interviewId: item.prepare.interviewId as InterviewId } : { type: "prepare", target: "review" }} />}
      </View>)}
    </>}

    {(career.promotion || job?.next) && <>
      <Kicker>Oportunidades</Kicker>
      {career.promotion ? <View style={styles.item}>
        <View style={styles.itemHead}><Text style={styles.itemTitle}>{career.promotion.title}</Text></View>
        <Text style={styles.itemSub}>{career.promotion.company} · processo interno até {shortDate(career.promotion.until)}</Text>
        <ActionRow label="Candidatar-se ao processo interno" meta="15 min" disabled={!career.promotion.canApply} reason={career.promotion.reason} command={{ type: "apply-internal" }} />
      </View> : job?.next && <View style={styles.item}>
        <View style={styles.itemHead}><Text style={styles.itemTitle}>{job.next.title}</Text></View>
        <Text style={styles.itemSub}>{job.company} · o próximo degrau</Text>
        <Text style={styles.gaps}>{job.next.gaps.length ? `Ainda falta: ${job.next.gaps.join(", ")}.` : "Você cumpre o que costuma ser pedido. Vale levar o assunto na conversa do mês."}</Text>
      </View>}
    </>}

    <Kicker meta={`${career.vacancies.length} abertas`}>Vagas</Kicker>
    {!career.vacancies.length && <Prose tone="secondary">Nenhuma vaga aberta agora. Novas vagas saem no jornal da cidade, em geral no começo da semana.</Prose>}
    {career.vacancies.map(v => <View key={v.id} style={styles.item}>
      <View style={styles.itemHead}>
        <Text style={styles.itemTitle}>{v.title}</Text>
        <Text style={styles.itemValue}>{v.salary}</Text>
      </View>
      <Text style={styles.itemSub}>{v.company} · pede {v.preparation.toLowerCase()} · {v.competition.toLowerCase()}</Text>
      {v.referral && <Text style={styles.referral}>{v.referral}</Text>}
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
  manager: { flexDirection: "row", alignItems: "flex-end", gap: space[4], marginTop: space[6], paddingBottom: space[3], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  managerText: { flex: 1, paddingBottom: space[1] },
  managerName: { color: colors.text, fontFamily: fonts.title, fontSize: 19, lineHeight: 24 },
  managerRole: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 },
  managerRelation: { color: colors.text, fontFamily: fonts.narrative, fontSize: 16, lineHeight: 23, marginTop: space[1] },
  actions: { marginTop: space[2] },
  agendaLabel: { color: colors.text, fontFamily: fonts.body, fontSize: 15, lineHeight: 22 },
  agendaTime: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 },
  item: { paddingTop: space[3] },
  itemHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", gap: space[4] },
  itemTitle: { flex: 1, color: colors.text, fontFamily: fonts.title, fontSize: 19, lineHeight: 24 },
  itemValue: { color: colors.text, fontFamily: fonts.medium, fontSize: 14, fontVariant: ["tabular-nums"] },
  itemSub: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: 2 },
  gaps: { color: colors.text, fontFamily: fonts.narrative, fontSize: 16, lineHeight: 23, marginTop: space[2] },
  referral: { color: colors.accent, fontFamily: fonts.medium, fontSize: 12, lineHeight: 18, marginTop: 2 },
})
