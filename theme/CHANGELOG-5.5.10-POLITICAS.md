# Game Overdrive 5.5.10 — Políticas e transparência

## Objetivo

Organizar os documentos institucionais do Game Overdrive em uma central única, com o mesmo design das páginas de confiança já existentes, sem inventar propriedades de schema nem publicar políticas sem revisão humana.

## Alterações

- Nova central `/politicas/`, provisionada como rascunho.
- Cinco políticas extras do `NewsMediaOrganization`, também provisionadas como rascunho:
  - `/propriedade-e-financiamento/`
  - `/missao-e-prioridades-de-cobertura/`
  - `/politica-de-diversidade/`
  - `/politica-de-assinatura/`
  - `/politica-de-fontes-nao-identificadas/`
- As páginas novas usam o mesmo `template-parts/trust-page.php` das políticas existentes.
- A navegação lateral institucional foi dividida em três grupos: Institucional, Políticas editoriais e Legal e acesso.
- A central de políticas monta cards apenas para documentos publicados; rascunhos nunca viram links públicos.
- O rodapé passa a destacar `Políticas e transparência` quando a central estiver publicada, sem poluir a lista principal com políticas individuais.
- O diagnóstico de E-E-A-T ganhou atalho para revisão das páginas quando ainda houver propriedades pendentes.
- `noBylinesPolicy` passa a ser apresentado ao editor como “Política de autoria e matérias sem assinatura”, evitando a ambiguidade de “assinatura”.

## Regra de publicação

O tema cria os documentos como **rascunho**. Isso é intencional: uma política pública é uma afirmação editorial. O schema só passa a emitir cada propriedade quando a página correspondente estiver publicada.
