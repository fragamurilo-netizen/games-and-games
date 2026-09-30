// Parâmetros de gameplay, não recomendações de saúde nem regras trabalhistas reais.
export const routineRules = {
  initialPantryMeals: 4,
  groceries: { priceCents: 4800, portions: 6, minutes: 60, capacity: 30 },
  work: { startMinute: 360, lastStartMinute: 840, shiftMinutes: 480, reminderMinute: 480, dismissalAbsences: 3, reapplyDays: 7 },
  meals: {
    home: { label: "Preparar comida em casa", minutes: 35, priceCents: 0, kcal: 650, hunger: -60, energy: 6, stress: -3 },
    restaurant: { label: "Comer no restaurante", minutes: 45, priceCents: 1800, kcal: 950, hunger: -70, energy: 8, stress: -4 },
    community: { label: "Almoçar no centro comunitário", minutes: 60, priceCents: 0, kcal: 750, hunger: -60, energy: 6, stress: -2 },
  },
} as const
