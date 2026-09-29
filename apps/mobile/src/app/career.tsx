import { Text, View } from "react-native"
import { queryCareer } from "@paralelo/simulation"
import type { CourseId } from "@paralelo/shared"
import { ScreenFrame, Section, ActionButton, pageStyles as s } from "../components/screen-frame"
import { useGame } from "../hooks/game-context"

export default function CareerScreen() {
  const { world } = useGame()
  if (!world) return null
  const career = queryCareer(world)
  return <ScreenFrame title="Trabalho e caminhos" subtitle="CARREIRA">
    {career.employment ? <>
      <Text style={s.heading}>{career.employment.title}</Text><Text style={s.body}>{career.employment.company}</Text>
      <Text style={s.secondary}>{career.employment.salary} por 20 turnos · segunda a sexta</Text>
      <Text style={s.secondary}>Turnos do mês: {career.employment.shifts} · A receber: {career.employment.accrued}</Text>
      <Text style={s.body}>{career.employment.performance}</Text>
      <ActionButton label="Ir trabalhar · 8 horas" command={{ type: "work" }} disabled={!career.canWork} />
      {career.unavailableReason && <Text style={s.secondary}>{career.unavailableReason}</Text>}
      {career.nextWork.waitMinutes > 0 && <ActionButton label={`Avançar até ${career.nextWork.date}, ${career.nextWork.time}`} command={{ type: "wait", minutes: career.nextWork.waitMinutes }} />}
    </> : <Text style={s.body}>Você ainda está procurando trabalho. As vagas abaixo existem nas empresas da cidade.</Text>}
    <Section title="Aprender uma profissão">
      {career.courses.map(course => <View style={s.row} key={course.id}>
        <Text style={s.heading}>{course.title}</Text><Text style={s.secondary}>{course.institution}</Text>
        <Text style={s.body}>{course.progress} · {course.price} por aula de 2 horas</Text>
        <ActionButton label={`Estudar ${course.title.toLowerCase()}`} command={{ type: "study", courseId: course.id as CourseId }} disabled={!course.canStudy} />
        {course.reason && <Text style={s.secondary}>{course.reason}</Text>}
      </View>)}
    </Section>
    <Section title="Vagas na cidade">
      {career.vacancies.map(vacancy => <View style={s.row} key={vacancy.id}>
        <Text style={s.heading}>{vacancy.title}</Text><Text style={s.secondary}>{vacancy.company}</Text>
        <Text style={s.body}>{vacancy.salary} por 20 turnos</Text>
        <ActionButton label={`Enviar currículo · ${vacancy.title}`} command={{ type: "apply-job", vacancyId: vacancy.id }} disabled={!vacancy.canApply} />
        {vacancy.reason && <Text style={s.secondary}>{vacancy.reason}</Text>}
      </View>)}
    </Section>
  </ScreenFrame>
}
