import { beginLife, createWorld, executeCommand, type Command, type StartProfile, type WorldState } from "@paralelo/simulation"
import type { LoadedSave, SaveError } from "@paralelo/persistence"
import type { Result } from "@paralelo/shared"

export interface SavePort {
  load(): Promise<Result<LoadedSave | null, SaveError>>
  save(world: WorldState): Promise<Result<void, SaveError>>
}
export type SessionSnapshot = Readonly<{ world: WorldState | null; busy: boolean; error: string | null; notice: string | null; needsStart: boolean }>
export type SessionOptions = Readonly<{
  /** sem save, espera o jogador escolher identidade e ponto de partida (bíblia §47) */
  onboarding?: boolean
  /** seed de uma nova campanha; a aplicação usa o relógio do aparelho, fora da simulação */
  newSeed?: () => string
}>

// Única dona do estado da campanha na aplicação. React apenas assina e envia comandos.
export class GameSession {
  private snapshot: SessionSnapshot = { world: null, busy: true, error: null, notice: null, needsStart: false }
  private readonly listeners = new Set<() => void>()
  private initialization: Promise<void> | null = null
  private operating = false
  constructor(private readonly saves: SavePort, private readonly initialSeed: string, private readonly options: SessionOptions = {}) {}
  getSnapshot = (): SessionSnapshot => this.snapshot
  subscribe = (listener: () => void): (() => void) => { this.listeners.add(listener); return () => { this.listeners.delete(listener) } }
  private publish(patch: Partial<SessionSnapshot>): void {
    this.snapshot = { ...this.snapshot, ...patch }
    for (const listener of this.listeners) listener()
  }
  initialize = (): Promise<void> => {
    if (this.initialization) return this.initialization
    const operation = async () => {
      this.publish({ busy: true, error: null })
      try {
        const loaded = await this.saves.load()
        if (!loaded.ok) { this.publish({ busy: false, error: loaded.error.message }); return }
        if (!loaded.value && this.options.onboarding) { this.publish({ busy: false, needsStart: true }); return }
        const world = loaded.value?.world ?? createWorld(this.initialSeed)
        // Também materializa migração ou recuperação; save igual preserva backup.
        {
          const saved = await this.saves.save(world)
          if (!saved.ok) { this.publish({ busy: false, error: saved.error.message }); return }
        }
        this.publish({ world, busy: false, notice: loaded.value?.recoveredBackup ? "Retomamos a cópia anterior da sua campanha." : null })
      } catch (error) { this.publish({ busy: false, error: error instanceof Error ? error.message : "Não foi possível abrir a campanha." }) }
    }
    this.initialization = operation().finally(() => { if (!this.snapshot.world) this.initialization = null })
    return this.initialization
  }
  /** Cria a campanha com o perfil escolhido e grava antes de mostrar. */
  start = async (profile: StartProfile, chosenSeed?: string): Promise<void> => {
    if (this.snapshot.world || this.operating) return
    const seed = chosenSeed ?? this.options.newSeed?.() ?? this.initialSeed
    const begun = beginLife(createWorld(seed), profile)
    if (!begun.ok) { this.publish({ error: begun.error }); return }
    this.operating = true
    this.publish({ busy: true, error: null })
    try {
      const saved = await this.saves.save(begun.value)
      if (!saved.ok) { this.publish({ error: saved.error.message }); return }
      this.publish({ world: begun.value, needsStart: false })
    } catch { this.publish({ error: "Não foi possível começar a campanha agora." }) }
    finally { this.operating = false; this.publish({ busy: false }) }
  }
  dispatch = async (command: Command): Promise<void> => {
    const world = this.snapshot.world
    if (!world || this.operating) return
    const result = executeCommand(world, command)
    if (!result.ok) { this.publish({ error: result.error.message }); return }
    this.operating = true
    this.publish({ busy: true, error: null, notice: null })
    try {
      const saved = await this.saves.save(result.value)
      if (!saved.ok) { this.publish({ error: saved.error.message }); return }
      this.publish({ world: result.value })
    } catch { this.publish({ error: "Não foi possível salvar. Sua ação ainda não foi aplicada." }) }
    finally { this.operating = false; this.publish({ busy: false }) }
  }
  save = async (): Promise<void> => {
    if (!this.snapshot.world || this.operating) return
    this.operating = true
    try {
      const result = await this.saves.save(this.snapshot.world)
      if (!result.ok) this.publish({ error: result.error.message })
    } catch { this.publish({ error: "Não foi possível salvar agora." }) }
    finally { this.operating = false }
  }
}
