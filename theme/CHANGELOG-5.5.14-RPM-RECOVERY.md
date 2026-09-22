# Game Overdrive 5.5.14 — RPM recovery guard

## O que foi corrigido

A comparação direta com o ZIP imediatamente anterior isolou duas mudanças da 5.5.13 que ampliavam oferta profunda sem dados de campo suficientes:

1. A escada de corpo passou a poder emitir A7/A8 automaticamente em matérias longas.
2. Reservas profundas passaram a poder ser solicitadas até meia viewport antes de entrarem na tela apenas porque o leitor estava engajado e parado próximo da posição.

A 5.5.14 mantém os IDs A7/A8 disponíveis, mas restaura **A6 como teto padrão de produção** (`GO_VERGE_ADS_ARTICLE_MAX_RUNG = 6`). A7/A8 só voltam mediante opt-in explícito via `wp-config.php`, permitindo testar um rung por vez com dados de receita e Active View por unidade.

O runtime de entrega foi restaurado integralmente para a versão anterior à intervenção, `12.7.0-context-paint-gate`. Nela, reservas precisam estar na viewport útil ou ter chegada predita pelo movimento real do leitor; não existe o caminho `engaged-near-reader` nem a reavaliação adicional introduzida na 12.8.0. Isso reduz variáveis durante a recuperação e protege qualidade/viewability.

## O que foi preservado

- loader único oficial do AdSense;
- `data-cfasync="false"`, `data-no-optimize="1"` e `data-no-defer="1"` no loader;
- exclusões LiteSpeed para runtime/configuração de anúncios;
- Top Scroll, Masthead, Hero, Sidebar, Multiplex e demais slots existentes;
- nenhuma alteração de ID de unidade, refresh, consentimento ou configuração privada da conta AdSense;
- todas as mudanças editoriais, de marca, políticas e categorias já presentes no pacote.

## Versões

- Tema: `5.5.14`
- Planner: `19.1.1-rpm-guard`
- Runtime: `12.7.0-context-paint-gate` (rollback seletivo para o último runtime anterior)

## Após instalar

Limpe cache de página, LiteSpeed/CDN e cache de assets. O runtime é servido inline em páginas monetizáveis; HTML antigo em cache pode continuar executando a 5.5.13.

A correção remove mecanismos concretos que poderiam degradar a qualidade do inventário, mas Page RPM também varia com mix de tráfego, demanda, cobertura e atraso do relatório. Para atribuição, compare horários equivalentes por unidade e acompanhe impressões/PV, RPM de impressão, cobertura e Active View.
