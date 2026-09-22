> Documento histórico. Para a configuração atual 5.5.0, siga `LEIA-ME-MOTOR-DE-ANUNCIOS.md`; a alternância local para Auto Ads in-page descrita em versões anteriores foi retirada.

# Game Overdrive 5.4.2

Instalador completo, baseado na 5.4.1 preservada. Inclui o ajuste solicitado do anúncio Masthead e uma correção no diagnóstico do corpo. A abertura editorial com foto, título e nota permanece intacta. Não há implantação automática nem mudança de conta.

## Masthead por tipo de matéria

No carregamento inicial em desktop (1101 px ou mais, conforme o breakpoint configurado), o anúncio `site-masthead` não é solicitado e não deixa espaço reservado em reviews, críticas e especiais. A classificação considera o post da consulta principal antes do loop, o formato do Editorial Desk, especiais com pacote próprio e fallbacks legados quando não há tipo explícito.

Mobile e tablet até 1100 px mantêm as regras anteriores. Notícias, guias, listas, home e arquivos mantêm o comportamento anterior. A regra não depende de user-agent: um HTML em cache é compatível com todas as larguras. Se um anúncio já tiver sido solicitado em uma largura permitida e a janela depois for ampliada, o criativo existente é preservado; não há remoção, refresh ou segunda solicitação.

## Diagnóstico preciso de posição

O painel administrativo de anúncios distingue marcadores Google antes do primeiro parágrafo, entre parágrafos, depois do último parágrafo e dentro de um parágrafo, além de auxiliares e exterior do artigo. Antes, qualquer marcador sob a raiz editorial fora de caixas conhecidas entrava no agrupamento `article-prose`, incluindo os localizados depois da prosa. O agrupamento anterior continua disponível, com a posição detalhada em campo separado.

Os estados `filled`, `unfill-optimized`, `unfilled` e desconhecido são separados. Totais são calculados antes do limite de amostragem. A coleta continua local, administrativa e sob demanda: não faz requisições, não dispara anúncios, não lê criativos e não muda conteúdo ou armazenamento. Seus números descrevem o DOM; não são receita, Active View ou impressões oficiais.

## Arquitetura preservada

O modo salvo é respeitado; uma atualização não troca a opção. Sem opção/constante/filtro específico, o padrão continua `manual_overlays`. Esse modo usa inventário manual e exige âncora e vinheta oficiais ativas na conta, com Auto Ads in-page desligado. A alternativa explícita `auto_overlays` continua disponível para uma decisão posterior e suspende todos os manuais do tema, preservando loader e consentimento.

Não foi escolhido um vencedor econômico entre Auto Ads e manual nesta atualização. Tampouco se usou a presença atual de hosts manuais como explicação para o relato de ausência entre parágrafos quando os manuais estavam desligados.

## Instalação e validação imediata

1. Guarde o ZIP 5.4.1 e mantenha acesso ao gerenciador de arquivos da hospedagem.
2. Em Aparência → Temas → Adicionar novo → Enviar tema, instale `news-magazine-x-5.4.2-final.zip`, substituindo a versão do mesmo tema.
3. Limpe os caches de página/CDN pelos controles já utilizados no site. Não altere consentimento ou os formatos da conta para validar esta mudança.
4. Em desktop, confira um review, uma crítica e um especial: nenhum espaço de Masthead deve anteceder a abertura editorial. H1, imagem e nota devem continuar presentes. Confira também uma notícia, na qual o Masthead mantém sua regra anterior.
5. Em mobile, confirme que o Masthead mantém a elegibilidade anterior e que o conteúdo permanece legível. Uma unidade elegível pode não receber anúncio; isso não é falha da regra por dispositivo.
6. No painel administrativo de anúncios, confira os contadores específicos de posição. Um marcador após o último parágrafo não deve ser contado como marcador entre parágrafos.

## Retorno à versão anterior

Reinstale o ZIP completo 5.4.1 e limpe os mesmos caches. Esta atualização não migra opções, conteúdo, tabelas ou configurações da conta. O modo salvo permanece o mesmo. Não misture arquivos isolados das duas versões durante o rollback.

## Limites reais

A inspeção ao vivo de 21/09 encontrou texto normal e sem clipping em uma aba existente, mas duas novas consultas HTTP de matérias receberam 403 com Bot Verification. Isso demonstra bloqueio daquele cliente, não bloqueio dos rastreadores Google. Logs da hospedagem e configurações de exclusão/recrawl do AdSense continuam necessários para concluir a causa. Esta versão não contorna a proteção da hospedagem e não é uma declaração de que Auto Ads ou Discover foram recuperados.
