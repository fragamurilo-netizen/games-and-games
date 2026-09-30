import type { LedgerId } from "@paralelo/shared"
import type { LedgerEntry, WorldState } from "../domain/world"

export function postLedger(world: WorldState, input: Omit<LedgerEntry, "id" | "at">): WorldState {
  if (!Number.isSafeInteger(input.amountCents)) throw new Error("Valor do ledger deve ser inteiro em centavos.")
  const entry: LedgerEntry = { ...input, id: `ledger:${world.nextId}` as LedgerId, at: world.clock }
  return { ...world, nextId: world.nextId + 1, finance: { ...world.finance, balanceCents: world.finance.balanceCents + entry.amountCents, ledger: [...world.finance.ledger, entry] } }
}
export const formatMoney = (cents: number): string => `${cents < 0 ? "−" : ""}R$ ${Math.floor(Math.abs(cents) / 100).toLocaleString("pt-BR")},${String(Math.abs(cents) % 100).padStart(2, "0")}`
