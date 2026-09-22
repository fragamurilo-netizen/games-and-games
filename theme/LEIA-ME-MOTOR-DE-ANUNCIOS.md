> **Versão vigente: 5.6.0** (runtime `13.0.0-value-first`, planner `20.0.0-value-first`). Leia primeiro `CHANGELOG-5.6.0-VALOR-POR-IMPRESSAO.md`: corrige o runtime inline que o Burst Statistics corrompia em produção, reduz impressões não vistas em rolagem rápida (`max_lookahead_vh` 1,8/1,6 e `fling_tau_s`) e posiciona a escada P1+A1–A6 por cadência de leitura em matérias longas. O restante deste guia descreve a 5.5.13/5.5.14 e continua válido onde não conflitar.

# Overdrive — motor manual 5.5.13

Esta é a configuração vigente. Os guias com versões anteriores registram o histórico e não devem orientar a configuração desta versão.

**Instalador completo:** `news-magazine-x-5.5.13-anuncios.zip`. Não requer instalar versões intermediárias. Tema 5.5.13; runtime `12.8.0-near-reader`; planner `19.1.0-contract-ladder`.

As mudanças desta versão estão em `CHANGELOG-5.5.13-ANUNCIOS.md`. A arquitetura manual + overlays e os limites de densidade permanecem. A7/A8 agora percorrem seleção e composição até o HTML; reservas próximas podem preparar após engajamento; o perfil acompanha a largura atual.

## Decisão de arquitetura

Uma configuração de produção: **anúncios manuais nas páginas + âncora e vinheta oficiais do AdSense**. A alternativa local `auto_overlays` foi retirada. Uma opção, constante ou filtro antigo de modo não suspende os manuais. A chave global de emergência continua válida; não deve ser usada para desligar apenas banners automáticos, pois o loader é compartilhado.

O tema não altera a conta Google. No AdSense, manter o recurso geral necessário aos formatos oficiais ligado, âncora e vinheta ligadas e formatos automáticos in-page desligados. Desligar também Encontrar mais posições, Otimizar anúncios existentes e trilhos laterais automáticos para preservar a distribuição manual pretendida. O Ads Center registra a conferência do operador; esse registro não é uma leitura automática do estado da conta.

## O que o reset faz

A política de entrega parte da tabela desta versão, sem acelerar ou frear conforme Page RPM, RPM de impressão ou a hora. Os relatórios e classificações econômicas permanecem no administrador. O comportamento do leitor, a largura útil, a latência de resposta, o preenchimento local e a proximidade continuam relevantes ao carregamento.

No primeiro acesso administrativo autorizado, a migração guarda a existência e o valor anterior das opções, fixa o modo manual e normaliza a opção local de Top Scroll para ligado/6. O Top Scroll usa esse preset em memória antes da migração, sem gravar opções durante visitas públicas. A migração é única, com invalidação de cache compatível; escolhas administrativas posteriores de Top Scroll são preservadas.

O reset não apaga IDs, credenciais, relatórios GOAC, escolhas de consentimento ou histórico de frequência do navegador. Constantes/filtros externos específicos de Top Scroll e controles de emergência continuam podendo alterar o valor efetivo; o diagnóstico registra essas exceções. O pacote não edita `wp-config.php`, plugins externos ou o painel AdSense.

## Configuração inicial escolhida

| Regra | Mobile | Desktop | Motivo |
|---|---|---|---|
| Perfil de entrega | Largura abaixo de 1101 px | A partir de 1101 px | Corresponde à disponibilidade da coluna lateral |
| Intervalo entre solicitações não críticas | 90 ms | 70 ms | Distribuir trabalho; anúncio visível ou prestes a ser alcançado pode passar imediatamente |
| Antecipação em repouso, por tier | 1,00 / 0,90 / 0,75 / 0,60 / 0,52 viewport | 0,85 / 0,78 / 0,65 / 0,55 / 0,50 viewport | Dar antecedência às posições de maior alcance; cauda fica próxima do leitor |
| Teto preditivo | 3,0 viewports | 2,6 viewports | Limitar solicitações muito distantes, mesmo com rolagem rápida |
| Intervalo base de conteúdo entre anúncios | 240 px | 300 px | Evitar empilhamento quando o HTML real difere da estimativa |
| Janela local, de cada lado | 0,90 viewport | 0,85 viewport | Avaliar contexto próximo, incluindo altura real dos criativos |
| Unidades máximas na janela | 3 | 3 | Um teto, não uma meta de ocupação |
| Parcela local máxima de publicidade | 45% | 42% | Conter concentrações; conteúdo editorial continua necessário |
| Relação global anúncio/conteúdo | 45% | 45% | Salvaguarda adicional no artigo |
| Intervalo base entre anúncios de listagem | 380 px | 460 px | Separar publicidade entre cards |

Os valores de antecipação são bases. A geometria, o teto do estado de leitura, a latência, a rede, o preenchimento observado e o histórico válido da unidade ainda influenciam o momento do pedido. Os intervalos geométricos também têm multiplicadores locais de estado de leitura; não dependem do RPM. Nada nesta tabela é uma autorização universal de política do Google.

O planner oferece **até P1 + A1–A8**, condicionado a comprimento, blocos substantivos, fronteiras editoriais, vizinhança de títulos/mídias e espaços seguros. Isso não significa nove impressões em toda matéria, nem limita todos os formatos do site a nove. A escada por palavras abre a oitava oportunidade a partir de 1.800 palavras e a nona a partir de 2.600; headroom estrutural e tipo editorial podem antecipar oportunidades quando houver fronteiras seguras. A ausência de um ID interrompe a escada naquele ponto. Posições externas e Article End têm seus próprios contextos. Não há inserção fixa após números de parágrafo.

A expansão antecipada usa 40% de profundidade e 18 segundos ativos, ou 58% de profundidade; o histórico local consentido pode antecipar essa elegibilidade. Uma reserva alcançada continua podendo entrar sem esperar essa expansão. Após engajamento local, uma reserva abaixo da tela pode preparar até meia viewport útil antes de aparecer, limitada também pela antecipação do tier, sem movimento de afastamento ou rolagem rápida. Largura, consentimento, densidade e capacidade estrutural continuam obrigatórios. O teto de preparação é 1,15 viewport no início e 1,25 em rolagem conservadora. Essas regras não aumentam nem diminuem com o resultado financeiro do dia.

## Top Scroll e Masthead

Top Scroll permanece móvel, em fluxo normal, com até seis preenchimentos por janela móvel de 24 horas quando é permitido guardar o histórico. Até a quarta oportunidade usa o fluxo normal; a quinta exige 3 páginas ou 60 segundos ativos acumulados na mesma sessão local da aba; a sexta, 4 páginas ou 120 segundos acumulados nessa sessão. A sessão local reinicia após 30 minutos de inatividade. Não existe uma espera obrigatória de 60/120 segundos por página. O motor não refaz o mesmo anúncio na mesma página. Sem permissão para persistência, não inventa um identificador para impor um limite entre páginas. A contagem de preenchimento local não comprova receita AdSense. A releitura de localStorage considera outras abas, mas o limite é de melhor esforço e não uma transação atômica entre leilões simultâneos.

**Reviews, críticas e especiais não solicitam o Masthead acima da matéria no desktop**, nem reservam seu espaço inicial. A abertura editorial, a imagem e a nota são preservadas. Mobile/tablet mantém seu comportamento anterior. Um anúncio já solicitado numa largura menor é preservado ao redimensionar; o tema não recorta ou esconde o criativo pago.

A1, A2 e A3 continuam Display responsivo, IDs 7131714626, 4505551284 e 5056215625. Não criar novas unidades para instalar este pacote. O desempenho das antigas unidades In-article não deve ser tratado como resultado destes IDs. F1–F5 continuam no pool finito das listagens elegíveis, sem reciclagem artificial de IDs.

## Otimizações incluídas

1. **Prioridade coerente com receita por solicitação.** A ordenação deixa de descontar cobertura duas vezes: o valor histórico por solicitação já inclui pedidos sem receita. A proximidade continua importante e a cobertura continua disponível no diagnóstico.
2. **Contagem fiel de inventário.** O composer conta hosts realmente emitidos e reivindica IDs na ordem de leitura. Unidades recusadas deixam de aparecer como inventário renderizado; um conflito de ID não dá preferência acidental à posição mais profunda.
3. **Nenhuma consulta de regime por pageview.** Os pesos históricos vêm no HTML. O runtime não faz o GET adicional para buscar o regime financeiro, inclusive ao encontrar configuração legada. Modelo antigo ou sem validade suficiente usa pesos neutros; não desliga posições.
4. **Sem controle financeiro oscilante.** Sinais financeiros globais não mudam ritmo, antecipação ou profundidade mínima. O painel continua mostrando receita e classificações para análise humana.
5. **Correções acumuladas preservadas.** Recurso de posição silenciosa liberado após 8 s sem repetir o anúncio; respostas tardias preservadas; unfilled não prende orçamento; reserva alcançada; consentimento tardio; memória autorizada de latência; retomada de página; fonte/minificado coerentes; continuidade de listagens; integridade do conteúdo e feeds de vídeo fora da resposta pública.
6. **CTAs editoriais preservados.** Games destaca jogos grátis e promoções; Tecnologia usa o canal próprio e texto adaptado ao assunto. A chamada não promete que um jogo pago específico seja grátis.

7. **Pool de listagens sem rank perdido.** A continuação do feed escoa qualquer identidade que o documento não gastou, em vez de consumir e descartar o rank recusado. Antes disso, um hub ou arquivo sem unidade pós-hero destruía F3 e empurrava F4/F5 para linhas mais profundas. Recuperar a identidade não promete preenchimento: o Google continua decidindo isso.
8. **Exposição local com o limiar do formato.** O relógio local passa a exigir 50% dos pixels, ou 30% quando o criativo tem 242.500 px² ou mais, sempre medido na viewport útil — descontando a faixa coberta por uma âncora exibida, como a entrega já fazia. Continua sendo observação local do DOM: não é Active View, impressão paga nem receita, e a entrega não lê esses campos.
9. **Origem do criativo aquecida no primeiro pedido.** `tpc.googlesyndication.com` recebe preconnect no momento do primeiro pedido, não no `<head>`, para não disputar sockets com o recurso de LCP. É dica de conexão: não busca nada e não cria impressão. Pode adiantar a pintura do criativo; não garante viewability nem preço.

10. **Prior de profundidade pela origem da visita.** A maioria das sessões aqui tem um pageview, e o modelo de leitor precisa de três antes de dizer algo — então o prior caía no neutro 0,5 justamente nas pageviews que mais importam. O runtime reduz `document.referrer` a um balde grosso em memória (`internal`, `google-app`, `aggregator`, `search`, `social`, `direct`, `app`, `other`) e usa o prior daquele balde até o leitor rolar; a partir daí a profundidade medida domina, como sempre. Nada é guardado: nenhuma URL, termo de busca ou identificador sobrevive à função, e por isso não depende de consentimento. O prior **não** abre reserva do planner — a expansão por leitor recorrente continua exigindo o histórico do próprio leitor. Valores presos entre 0,35 e 0,72; ajuste por `go_verge_ads_entry_context_priors`.
11. **Portão de primeira pintura (DESLIGADO por padrão; ligue por `go_verge_ads_cwv_guards`).** Posição não crítica, fora da viewport e a mais de meia tela da dobra espera a primeira pintura assentar antes de pedir — o único caso em que um request disputa soquetes e main thread com o elemento de LCP sem ganhar nada. Solta na entrada de LCP mais 250 ms, na primeira interação, ou no teto de 1,2 s. Crítico, visível e prestes a ser alcançado passam intactos, pela mesma régua do critical hold. É adiamento com prazo: a oferta não muda.
12. **Reserva no momento do pedido.** A escada do corpo declara reserva zero para não deixar buraco quando não preenche, e isso fazia a chegada do criativo ser a própria mudança de layout. Agora o espaço previsto é reservado no pedido e **só enquanto o host está inteiramente abaixo da viewport útil**, onde crescer não desloca nada visível. `unfilled` continua colapsando para nada; posição que não pediu continua ocupando zero.
13. **Limite de frequência vale onde foi declarado.** O preenchimento já era gravado para qualquer posição com limite, mas só o Top Scroll lia de volta. Leitura e escrita concordam. Não muda nada nesta configuração — só o Top Scroll declara limite — e passa a valer quando alguém declarar um segundo.

`nearMax` permanece identificado como parâmetro legado sem efeito no diagnóstico. Não foi tratado como causa automática de perda. `floor_scale` é um indicador analítico do servidor; não define lance, CPM mínimo nem remuneração do Google.

## Testes por dia de calendário

O motor não tinha como responder se uma mudança rendeu mais. Comparar "antes" e
"depois" não responde: mix de tráfego, demanda e sazonalidade se movem entre os
dois períodos e nenhum cuidado separa isso da mudança.

A unidade de atribuição é o **dia**, nunca o leitor. Um dia inteiro roda um
braço; o dia seguinte roda o próximo. Todo leitor daquele dia vê o mesmo motor, e
o relatório por dia do AdSense — que o Ads Center já sincroniza — separa os
braços com a receita real, sem dimensão customizada e sem nada para o tema
contar. Como o rodízio anda um dia por vez e a semana tem sete, em catorze dias
cada braço recebe cada dia da semana exatamente uma vez: o fim de semana entra
nos dois lados em vez de pertencer a um.

Um braço só move tempo e espaçamento (`rest_lead_vh`, `min_gap_px`,
`request_spacing_ms`, `max_lookahead_vh`, `flick_vh_s`, `engage_*`). O envelope
de densidade — unidades por janela, parcela local, relação anúncio/conteúdo —
**não é ajustável por um teste**, e o runtime re-limita todo valor que recebe.
Um teste sem data de início, com menos de dois braços, com a linha de base
alterada, ou dois testes habilitados ao mesmo tempo: **nenhum** roda.

Declare por `go_verge_ads_trials` (exemplo desligado em
`inc/ads/calendar-trials.php`) e leia em **Ads Center → Testes por dia**. Lá, a
contagem de **rodadas a favor** vale mais que a média: perto de metade, a
diferença é ruído do dia a dia por maior que a média pareça.

Um dia de calendário não é unidade controlada. Um ciclo de notícias, uma queda ou
uma alta no Discover pertencem ao braço dono daquela data. O desenho remove o que
varia devagar; não remove um evento de um dia só e **não estabelece causa**.

## Instalação

1. Guardar o ZIP anterior e um backup do banco/opções. O instalador contém todos os arquivos do tema.
2. Em Aparência → Temas → Adicionar novo → Enviar tema, enviar `news-magazine-x-5.5.13-anuncios.zip` e substituir a versão do mesmo tema.
3. Abrir uma página administrativa como administrador para concluir e registrar as migrações. Conferir o modo manual e o Top Scroll efetivo no Ads Center/diagnóstico.
4. Invalidar cache de página, LiteSpeed/CDN e assets. A migração solicita limpeza das integrações compatíveis, mas não confirma que toda camada externa aceitou ou propagou essa limpeza. HTML antigo pode conter o runtime antigo inline.
5. Conferir a configuração da conta descrita acima. Nenhuma etapa do tema modifica aqueles seletores Google.
6. Confirmar tema 5.5.13 e `GOAdsRuntime.inspect().version === '12.8.0-near-reader'` em uma página elegível. Abrir uma matéria normal e uma review/crítica/especial no desktop; conferir Masthead, texto, hero, CTA e ausência de sobreposição.

## Verificação depois de instalar

Conferir loader único, consentimento, posições próximas, ausência de pedidos duplicados, estados unfilled/optimized/sem resposta, navegação voltar e orientação. Evitar recargas repetidas para produzir publicidade. O inspetor local explica estados e exposição; seus números não são Active View nem receita confirmada.

Nas primeiras 24–48 horas, usar os registros para encontrar regressões evidentes. Depois comparar dias fechados e horários equivalentes: receita total, Page RPM por totais, RPM de impressão, impressões/PV, cobertura, mensurabilidade/Active View, contribuição dos manuais/âncora/vinheta e sessões compatíveis do GA4. Manter a mesma configuração de produção. **Não existe sorteio de grupos neste pacote** e não existe divisão de audiência: dois leitores que abrirem a mesma página no mesmo minuto recebem sempre a mesma configuração. O que existe, desde 5.5.2, é o teste por **dia de calendário** — um dia inteiro roda um braço, o seguinte roda o outro, e o relatório diário do AdSense separa os braços sozinho. Ele vem desligado; enquanto estiver desligado, a tabela publicada vale para todos os dias. Ver a seção abaixo. Comparação antes/depois sofre influência de tráfego e demanda e não fornece causalidade perfeita.

A validação e as correções atuais estão em `CHANGELOG-5.5.13-ANUNCIOS.md`; os arquivos de versões anteriores registram o histórico. Nenhum teste de laboratório prova maior receita, preenchimento real ou Core Web Vitals de campo. Metas de campo: LCP ≤ 2,5 s, INP ≤ 200 ms e CLS ≤ 0,1, no percentil 75 por dispositivo.

## Rollback

Reinstalar o ZIP anterior e invalidar as mesmas camadas de cache. O retorno dos arquivos é independente do banco: se quiser restaurar também as opções, usar os valores anteriores guardados pelas migrações ou o backup do banco. Não apagar marcadores enquanto permanecer nesta versão, pois isso poderá solicitar novamente o reset. Os relatórios, IDs e contadores consentidos dos leitores não foram apagados. Para retorno exato, prefira o snapshot anterior de arquivos e banco: versões antigas também possuem sua própria migração de frequência. Backups locais: `go_verge_ads_manual_architecture_backup_v1` e `go_verge_topscroll_manual_baseline_backup_v1`.

Não foi feita implantação por esta auditoria. A versão elimina mecanismos demonstráveis de perda/complexidade; não garante US$ 4 por mil páginas nem torna o RPM crescente a cada atualização do relatório.
