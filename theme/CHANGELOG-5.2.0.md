# Game Overdrive 5.2.0

Data de preparação: 21/09/2026. Base: 5.1.1. Runtime: 12.4.0-responsive-geometry.

## Anúncios e exposição

- Remove o limite CSS específico do corpo que anulava a liberdade de expansão de unidades com `data-full-width-responsive=true`.
- Restringe a ocultação por largura da lateral de jogos a posições ainda não solicitadas. O mesmo INS e seu criativo permanecem no documento após resize.
- Espera dimensões válidas da viewport antes de solicitar; recupera o pedido quando a geometria aparece, sem repetição.
- Concede sticky apenas quando wrapper, criativo, rótulo e offset cabem na viewport desktop. Quando não cabem, usa fluxo normal.
- Verifica interseção do sticky com âncora oficial reconhecida, incluindo topo, rodapé e laterais. Observadores locais reavaliam mudanças posteriores sem polling e sem mover os elementos do Google.
- Mantém o estado de reprovação de tamanho até uma mudança pertinente de geometria, evitando oscilar durante reflows de uma resposta tardia.
- Mantém a lateral de jogos em fluxo normal quando a barra local `.od-game-nav` está presente, eliminando o conflito de posições fixas sem remover a unidade.
- Expõe razão e geometria do sticky nos diagnósticos locais. A instrumentação não passa a representar Active View ou receita oficial.
- Corrige comentários do renderer que prometiam primeiro paint e maior demanda sem que o comportamento justificasse essas garantias.

## Metadados e descoberta

- Alinha datas Open Graph do Rank Math ao relógio editorial utilizado pela matéria e pelo Article.
- Alinha `WebPage.datePublished` já existente à publicação original resolvida pelo tema.
- Corrige a normalização do RSS para atributos com aspas simples e espaços em torno do sinal de igual e para origem WordPress em subdiretório.
- Faz o diagnóstico Discover considerar o provider SEO ativo e distinguir regras robots específicas de bloqueio global.
- Faz o News Sitemap seguir elegibilidade e títulos do provider SEO ativo, com fallback editorial e invalidação das dependências de título.
- Expira o cache News na próxima fronteira de 48 horas e revalida XML em cache antes do envio.
- Preserva ETag no Fresh e remove a validação If-Modified-Since que usava relógio incompatível com a janela móvel.
- Restringe o reconhecimento de canonical próprio a equivalências válidas; não apaga overrides com parâmetros/identificadores/portas distintos.

## Canal de Tecnologia e integração

- Incorpora `https://whatsapp.com/channel/0029Vb8lV4nFi8xiDKv2mT08` ao convite de canal existente no corpo.
- Usa editoria atribuída, categoria principal, ancestrais e assunto canônico para adaptar a chamada a celulares, IA, Windows, computadores, TVs/monitores, áudio, wearables, apps/software, ciência ou Tecnologia geral.
- Preserva canais das demais editorias, precedência turca, convites salvos pela redação e cartão de compartilhamento.
- Restaura a proteção estrutural de pausas para convites/compartilhamento/recirculação usando o planner vigente, em vez de depender de funções semânticas ausentes. Unidades de anúncio não são removidas para acomodar o convite.

## Preservado

Política única de reservas alcançadas, continuidade F4/F5, memória consentida de latência, Top Scroll local até seis preenchimentos/24h, recuperação após consentimento tardio, loader oficial, âncora/vinheta e relatórios úteis. IDs e tipos das unidades existentes não mudam. Não há novos canais de experimento, refresh, rede externa ou Auto Ads in-page.

## Instalação e reversão

Atualize o tema e limpe os caches de página/assets/CDN; não basta trocar um JS se o HTML anterior continua em cache. Reverter o ZIP reverte o código após a mesma limpeza. A migração persistente de frequência do Top Scroll incorporada na 5.1.1 não é desfeita somente pela troca de arquivos.

Esta versão não regrava datas editoriais, conteúdos ou permalinks nem aplica redirects por semelhança. O estreitamento da limpeza de canonical previne exclusões indevidas futuras; ele não restaura valores apagados por versões anteriores.

## Validação

Resultados completos em `VALIDACAO-5.2.0.md`. Foram usados testes locais com dublês e respostas simuladas, fontes oficiais de hooks e capturas HTTP de leitura. Simulação não comprova ganho de receita, retorno ao Discover ou CWV de campo. A instalação e mudanças da conta não foram executadas.
