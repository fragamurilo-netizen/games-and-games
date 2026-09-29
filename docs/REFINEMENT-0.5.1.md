# Mais Uma Rodada 0.5.1: refinamento de realismo

## Base e escopo

Base: `6e3f472d6532090e73d799c1f0f6c221e97c0ec7` (0.5.0 validada), que já inclui as correções de paisagem/tablet do PR54 e as mudanças posteriores da branch `claude/project-thread-nzso8z` até `4f90c3eec4c4cc891f6e4d9710bf7a681742a838`.

Esta entrega é incremental. Preserva os 13 estilos coletivos, playstyles adicionais, comando/preparação de seleções, calendário internacional, kits autorais e três torneios de base da 0.5.0. Não duplica esses sistemas nem incorpora as iluminações experimentais. A branch original e os APKs publicados não são substituídos.

## Gols, assistências e estatísticas

- Contagem de resultado protegida contra reaplicação de uma partida/rodada. Suplentes sem minutos não recebem participação.
- Registro separado por jogador, clube, competição e temporada. Os números anteriores a uma transferência não passam a pertencer ao clube novo.
- No motor em lote, o tipo de lance e a função/atributos em campo escolhem o finalizador. Cabeceio e chute de longe também usam a competência de conversão correspondente. Não há quota máxima de gols por jogador.
- Pênaltis, gols contra e faltas diretas não geram assistências. O criador é escolhido antes do desfecho; passes decisivos não somam a assistência convertida novamente.
- xG é acumulado antes de se conhecer o resultado da finalização. A estimativa antiga derivada do número de gols não é usada quando existem dados observados do motor.
- Qualidade das chances: os multiplicadores táticos agora têm retornos decrescentes, de forma simétrica, com calibração comum de qualidade não penal. Não se consulta placar, usuário ou artilharia. Pênaltis mantêm o modelo próprio.
- Painel de produção por 90 minutos com gols, assistências, npxG, xA de finalização, minutos, chutes, chutes no alvo e passes decisivos. Exposição inferior a 450 minutos é sinalizada como amostra pequena.
- xA de finalização significa a soma do xG dos chutes após o passe. É um indicador do modelo próprio, não a reprodução do modelo proprietário de xA da Opta. Desarmes, interceptações, dribles e percentual de passes que não são eventos do motor continuam estimados e não foram convertidos em rastreamento completo.
- O histórico gerado antes de começar uma carreira considera titularidade, entradas do banco e nível plausível na idade correspondente. Totais de um save antigo não são diminuídos arbitrariamente, e o novo painel não inventa xG retrospectivo.

## Diretoria, caixa e negociações

- Caixa do clube e verba do treinador são conceitos separados na interface. A diretoria autoriza orçamento considerando receita, folha, custos, reservas e parcelas futuras. Não há favorecimento da política orçamentária pela dificuldade.
- Uma nova temporada substitui a autorização anterior. A sobra de verba não se acumula como carteira do técnico. O caixa contábil do clube continua existindo.
- Revisões e liberações extraordinárias são limitadas e não podem ser repetidas para gerar verba. Conversas, invencibilidade e eventos que liberavam dinheiro foram encaminhados à mesma verificação de disponibilidade. Patrocínio/receita não vira automaticamente autorização integral para compras.
- Compra parcelada compromete a taxa inteira no orçamento; só o vencimento atual sai do caixa. Cada pagamento identifica devedor, vendedor e eventual percentual de revenda. O vendedor não recebe o valor completo antes do comprador pagar. Trocar de emprego não muda o devedor.
- Luvas e comissão não são cobradas duas vezes pelo mesmo retorno de negociação. Pré-contratos reservam salários futuros e pagam/reservam as luvas ao assinar; empréstimos também respeitam caixa, teto salarial e autorização.
- Pedido salarial individual estável para os mesmos termos: repetir a oferta não sorteia uma aceitação nova. Projeção observável substitui consultas ao potencial oculto em mais decisões do mercado e nas sugestões do diretor.
- Interface mostra custo do contrato e compromissos. Não foi implementada uma negociação totalmente nova com árvores de conversa, promessas de minutos fiscalizadas ou todos os bônus contratuais existentes no futebol real.

## Categorias de base e eventos

- Cinco focos individuais: equilibrado, técnico, tático, físico e recuperação. Redistribuem a evolução normal, não dão pontos gratuitos. O plano registra clube, foco e carga/minutos observados.
- Condição e lesões pesam no desenvolvimento. Recuperação não pode ser aplicada repetidamente no mesmo dia. Orientação de promoção usa a rotação da função, não apenas o pior profissional do elenco.
- Venda de atleta da base verifica caixa, orçamento e salário do comprador. Os três torneios existentes continuam com histórico, elegibilidade e minutos, sem duplicar a participação do atleta.
- Quatro tipos novos de eventos contextuais: carga de trabalho, contrato perto do fim, aproveitamento da base e revisão orçamentária. As escolhas têm consequência limitada e proteção contra duplicação.
- O evento antigo de treino especial deixa de aumentar overall instantaneamente; passa a direcionar o treino normal. Mudanças de salário por eventos também precisam caber na folha.

## Interface e aparência

- Correção compartilhada de contraste para estados normal, hover, pressionado e foco nos botões do tema. Mantém a identidade do clube, com leitura do texto/ícones sobre o fundo.
- Grade de numeração responsiva, sem a extensa lista inicial de chips. Seleção de jogador em modal, nomes longos com tratamento de largura e confirmação para trocar uma camisa ocupada. Trocar número não dá moral ilimitada.
- Cartões só viram duas colunas quando há largura útil suficiente. Bases de celular e tablet já validadas são preservadas.
- Dimensionamento de modais considera bordas, alça, área segura e rotação enquanto estão abertos. Formulários compridos permanecem roláveis; fechar libera as conexões de redimensionamento.
- Correção de referência a tela descartada quando a raiz da interface é recriada. A primeira execução de regressão reproduziu um encerramento nesse fluxo; após a correção, o cenário passou. Isso não prova que os fechamentos relatados pelo usuário tenham todos a mesma causa.
- Seis cabelos e quatro barbas adicionados ao catálogo, com borda/densidade ajustadas nas novas barbas. Índices antigos preservados. Novos personagens podem receber as variantes; rostos existentes não são sorteados de novo.

## Validação reproduzível

Godot 4.7.stable.official.5b4e0cb0f. Os scripts estão em `tests/`:

- `refinement_bootstrap.gd`: também executa a suíte da 0.5.0; 600 partidas adicionais (100 nativas e 500 em lote), invariantes de estatísticas, pagamentos, reservas de pré-contrato, eventos, base, serialização e interface.
- `mobile_regression.gd`: regressões anteriores de rotação/ciclo de vida.
- `refinement_season_bootstrap.gd`: uma temporada inteira de um mundo de 980 clubes e 26.758 jogadores iniciais. Soma gols individuais + gols contra e compara com todos os placares de liga; executa também o encerramento de temporada. Não inclui os playoffs de liga na contagem de jogos corridos.
- `refinement_visual.gd`: capturas reais via OpenGL em 720x1280, 1280x720 e 1500x1100. Numeração, finanças, estatísticas, base, contratos, modo claro e catálogo cosmético. São personagens/dados sintéticos do jogo, não fotos geradas.
- `refinement_calibration_bootstrap.gd`: amostras pareadas com contexto igual entre os dois motores. Não exige resultados iguais entre modelos diferentes nem é uma calibração empírica completa.

A execução local final da temporada produziu 14.864 partidas de liga, 37.348 gols, 36.538 gols de jogadores e 810 gols contra, sem diferença de contagem. Média 2,513 gols por partida. Este é UM mundo/semente, não prova de fidelidade estatística geral. O relatório de CI acompanha o APK e é a referência da compilação distribuída; tempos/estatísticas podem diferir entre cenários.

## Instalação e limites

Versão 0.5.1, código Android 14, arm64. A cópia de avaliação usa `com.maisumarodada.futebol.refinetest` e nome `Mais Uma Rodada 0.5.1 Teste`. Não desinstalar o original. Carreiras de outros pacotes não são importadas automaticamente. A configuração de produção no código permanece `com.maisumarodada.futebol`.

Ainda sem Android físico, campanha de vários anos, migração de save real do usuário, métricas de FPS/bateria ou auditoria visual manual de todas as telas. O comando internacional ainda é convocação e preparação, não controle ao vivo com substituições manuais. Calendário internacional e academias adversárias mantêm as simplificações documentadas na 0.5.0. Preços são estimativas do jogo, não cotações atuais do Transfermarkt. Não se afirma que todo o realismo, toda a UI ou todos os freezes estejam resolvidos.

Referências conceituais: definições públicas de eventos da Stats Perform/Opta para distinguir gol, assistência e passe decisivo; documentação oficial do Godot para ScrollContainer e tamanho mínimo. Os parâmetros probabilísticos e financeiros são escolhas do modelo, não regras oficiais nem estatísticas empiricamente certificadas.
