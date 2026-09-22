> Documento histórico. Para a configuração atual 5.5.0, siga `LEIA-ME-MOTOR-DE-ANUNCIOS.md`; a alternância local para Auto Ads in-page descrita em versões anteriores foi retirada.

# Game Overdrive 5.4.0 — versão final do laboratório

Este é o tema completo. Instale **news-magazine-x-5.4.0-final.zip**; não é necessário aplicar versões intermediárias. O pacote mantém o motor manual como padrão e acrescenta um modo explícito para uma futura avaliação do Auto Ads, sem duplicar o loader nem desativar o consentimento.

- Tema: **5.4.0**; runtime manual: **12.5.0-delivery-integrity**.
- Publisher: **ca-pub-3687004010207904**.
- Padrão: **manual_overlays**, com posições manuais e formatos oficiais de âncora/vinheta preservados.
- Nenhuma configuração da conta Google é alterada pelo instalador ou pela seleção do modo local.
- Canal contextual de Tecnologia: **https://whatsapp.com/channel/0029Vb8lV4nFi8xiDKv2mT08**.

## Instalação

1. Guarde o ZIP anterior, o backup normal do banco e os valores das opções de monetização. Registre também a configuração atual dos formatos na conta Google.
2. Envie o instalador por **Aparência → Temas → Adicionar novo → Enviar tema** e substitua a versão do mesmo tema. Mantenha o tema filho e as personalizações externas no backup.
3. Invalide o cache do HTML e dos assets no WordPress/CDN. Confirme a versão 5.4.0 no tema e que as respostas novas deixaram de apontar para assets antigos.
4. Em **Ads Center → Modo de entrega**, confirme **manual_overlays**. Se o menu externo não estiver disponível, procure a página de modo em **Ferramentas**. Constantes ou filtros podem tornar a escolha do banco não efetiva; a tela identifica esses controles.
5. Na conta AdSense, preserve o recurso geral necessário aos formatos oficiais e mantenha **âncora e vinheta ligadas**. No modo manual, mantenha banners/inserções automáticas in-page, encontrar mais posições e otimizar anúncios atuais desligados.
6. Faça uma inspeção humana de matéria curta, longa, Tecnologia, listagem e `/videos/`, em mobile e desktop. Confira conteúdo, consentimento, reservas, anúncios reais, menu, CTA e sobreposições. Não automatize solicitações publicitárias.

O pacote foi validado localmente, mas não foi implantado nem executado contra o banco e o conjunto de plugins da produção. A validação real de cache, Google e hospedagem faz parte da instalação.

## Correções desta versão

**Integridade do artigo.** Uma falha de expressão regular na limpeza inicial não pode substituir todo o corpo por uma string vazia. A limpeza de parágrafos vazios também passa a preservar comentários, JSON, scripts, templates e blocos de código. Os casos que falhavam foram reproduzidos antes da correção; não foi identificada uma matéria publicada afetada por esses casos específicos.

**Disponibilidade de `/videos/`.** A página passa a ler feeds em cache, sem fazer chamadas HTTP externas durante a resposta ao visitante. O worker atualiza o cache por cron ou WP-CLI explícito, com deduplicação, expiração e proteção contra trabalho concorrente. O WordPress precisa executar os eventos agendados. Cache ausente mantém o conteúdo editorial de fallback; cache antigo tem limite de sete dias. Essa correção não explica, por si só, a lentidão de todas as matérias.

**Modo de entrega.** `auto_overlays` suprime todas as posições manuais do tema, reservas, rodízio, CSS e runtime manuais, mas mantém o loader oficial e as regras de consentimento. Não use a chave global `GO_ADS_V3_ENABLED=false` para desligar apenas os manuais: ela desativa recursos compartilhados. Não há alocação automática de visitantes em grupos.

**Diagnóstico fiel.** O painel distingue modo do código, declaração local dos controles da conta e evidência do HTML. IDs personalizados válidos não são tratados como falha crítica. Receita residual não é atribuída automaticamente à âncora/vinheta. Um novo coletor local permite descrever o corpo e a localização de marcadores sem fazer requisições adicionais.

O runtime manual 12.5.0 é o mesmo validado na 5.3.0. Permanecem as correções acumuladas de reservas alcançadas, F4/F5, densidade local, consentimento tardio, memória autorizada de latência, frequência Top Scroll e remoção de restrições adicionais arbitrárias por horário.

## Auto Ads e a orientação do suporte Google

A classe exata mencionada pelo suporte é **go-author-lead__body**. Ela já não é emitida pelo tema atual e não apareceu nas capturas atuais analisadas. Esta versão não atribui a si uma remoção que já havia ocorrido.

Para uma futura avaliação do Auto Ads, selecione `auto_overlays` no tema e coordene a ativação in-page na conta. Confira cache e HTML após a mudança. A configuração do Google e a local não são uma transação única; um estado intermediário pode gerar lacuna ou combinação não pretendida de inventário.

Se for seguido o procedimento sugerido pelo suporte para reavaliar a estrutura, registre o horário e o formato in-page alterado na conta. Preserve âncora e vinheta. A sugestão do suporte não equivale a um comando de recrawl nem garante inserção na prosa. O tema não modifica classes para enganar o pipeline do Google.

## Diagnóstico sob demanda

O administrador pode executar `GOAdsDiagnostics.collectArticle()` ou exportar o diagnóstico pela ferramenta administrativa. Ela registra raiz do artigo, parágrafos, dimensões/estilos disponíveis naquele navegador e marcadores classificados entre prosa, componentes auxiliares, hosts manuais e exterior do artigo.

A coleta não dispara anúncios, não acessa o conteúdo dos iframes e não envia telemetria. Ela observa apenas a página aberta. Uma sessão administrativa pode receber HTML/cache diferente do visitante anônimo. `push`, marcador no DOM e `filled` não são comprovantes de receita, e o diagnóstico próprio não é Active View.

## Operação e sucesso

Registre o horário da atualização. Nas primeiras 24–48 horas, procure falhas de conteúdo, HTTP/PHP, consentimento, cache misto e regressões de entrega. Calcule RPM a partir dos totais e acompanhe receita, impressões/PV, valor por impressão, cobertura, exposição e audiência em janelas completas de sete e 14 dias.

LCP ≤ 2,5 s, INP ≤ 200 ms e CLS ≤ 0,1 são metas no percentil 75 por dispositivo. O laboratório não mediu esses percentis nem executou criativos reais. A aprovação local está em **VALIDACAO-5.4.0.md**.

Nenhum código consegue impor CPM, recuperar Discover por comando ou garantir Page RPM de US$ 4 todos os dias. Esta versão corrige perdas técnicas reproduzidas, preserva oportunidades legítimas e melhora a capacidade de identificar a origem de falhas futuras.

## Rollback

Reinstale o ZIP anterior e invalide os mesmos caches. Restaure explicitamente as opções alteradas quando necessário: reinstalar arquivos não desfaz a migração Top Scroll nem uma escolha persistida de modo. Se a conta tiver sido alterada para uma avaliação Auto Ads, restaure a configuração correspondente à arquitetura de retorno; não desligue âncora/vinheta como atalho.

Consulte **LEIA-ME-MOTOR-DE-ANUNCIOS.md**, **CHANGELOG-5.4.0.md** e **VALIDACAO-5.4.0.md**. Documentos de versões anteriores são histórico. Dados privados, capturas, relatórios e código histórico estão no dossiê separado, que não deve ser publicado no WordPress.
