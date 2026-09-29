import type { GameDate } from "../domain/world"

export const absoluteMinute = (date: GameDate): number => date.day * 1440 + date.minute
export function fromMinute(value: number): GameDate {
  const day = Math.floor(value / 1440)
  return { day, minute: value - day * 1440 }
}
export const addMinutes = (date: GameDate, minutes: number): GameDate => fromMinute(absoluteMinute(date) + minutes)
const leap = (year: number) => year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0)
const monthDays = (year: number) => [31, leap(year) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
export function calendarDate(day: number): Readonly<{ year: number; month: number; day: number }> {
  let remaining = day + 4
  let year = 2026
  while (remaining < 0) { year--; remaining += leap(year) ? 366 : 365 }
  while (remaining >= (leap(year) ? 366 : 365)) { remaining -= leap(year) ? 366 : 365; year++ }
  let month = 1
  for (const days of monthDays(year)) { if (remaining < days) break; remaining -= days; month++ }
  return { year, month, day: remaining + 1 }
}
export function dayFromCalendar(year: number, month: number, day: number): number {
  let offset = -4
  for (let y = 2026; y < year; y++) offset += leap(y) ? 366 : 365
  for (let y = year; y < 2026; y++) offset -= leap(y) ? 366 : 365
  for (let m = 1; m < month; m++) offset += monthDays(year)[m - 1] ?? 0
  return offset + day - 1
}
export function ageAt(birth: GameDate, now: GameDate): number {
  const b = calendarDate(birth.day), n = calendarDate(now.day)
  return n.year - b.year - (n.month < b.month || (n.month === b.month && n.day < b.day) ? 1 : 0)
}
export const formatTime = (date: GameDate): string => `${String(Math.floor(date.minute / 60)).padStart(2, "0")}:${String(date.minute % 60).padStart(2, "0")}`
export function formatDate(date: GameDate): string {
  const c = calendarDate(date.day)
  return `${c.day} de ${["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"][c.month - 1]} de ${c.year}`
}
