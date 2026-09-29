# Mais Uma Rodada 0.5.1: integração e refinamento

Base de origem revisada: `39dc959cea476dceba7c98b7c187662522a18eaa`, branch `claude/project-thread-nzso8z` (29/09/2026).
Integra os recursos do incremento 0.5.0 (`6e3f472d6532090e73d799c1f0f6c221e97c0ec7`) sobre essa base, preservando a apresentação, estabilidade e distribuição de finalizações mais recentes. Desenvolvimento isolado em `codex/realism-integration-0.5.1-20260929`. Não substitui a branch original.

## Motor e estatísticas

Mantém dificuldade por decisões, não por um bônus oculto contra o usuário. Confrontos usam atributos, condicionamento e instruções. Preserva os pesos mais recentes de finalizadores/assistentes, sete estilos coletivos adicionais (13 no total) e 16 playstyles extras da 0.5.0.

`SeasonManager._apply_match` não aplica duas vezes o mesmo Fixture; `finish_matchday` reaproveita o relatório já finalizado e rejeita uma data obsoleta. Assim, chamadas repetidas não duplicam gols, assistências, minutos, tabela e registro do treinador. A verificação de contabilidade compara gols individuais + gols contra ao placar e limita assistências à quantidade de gols elegíveis. Não há corte arbitrário de gols para forçar uma média.

No perfil, números da liga têm rótulo explícito e taxas de gols, assistências e xG por 90 minutos só são comparadas após 270 minutos. Estatísticas estimadas do modelo são identificadas. A amostra de 240 jogos de contabilidade repete os mesmos dois elencos em partidas independentes; NÃO é uma temporada e seus totais individuais não são recordes de temporada nem uma prova de calibração empírica.

## Orçamento e negociações

Novo `BoardBudget`: autorização anual, custos comprometidos, parcela autorizada das vendas, concessões extras, retenções, histórico e revisão única. Reabrir uma tela, pedir o mesmo aporte ou recalcular a temporada não reabastece orçamento. O caixa pertence ao clube; o técnico só pode comprometer a verba autorizada e liquidez após provisões.

Uma compra compromete o preço fixo inteiro, comissão e luvas. Parcelas mudam a data de pagamento, não devolvem orçamento. O vendedor recebe caixa conforme as parcelas. Obrigações registram comprador e vendedor: trocar de clube não leva a dívida para o novo empregador. Vencimentos já pagos são removidos. Luvas em pré-contratos são reservadas na assinatura e não consomem orçamento novamente na chegada. Receitas futuras e custos de caixa aparecem separados na negociação e na tela do clube.

Esta é uma modelagem de gestão, não contabilidade regulatória completa. Não foram implementadas todas as regras específicas de fair play financeiro, impostos ou contratos de cada federação. Juros, bônus condicionais complexos e cronogramas mensais de transferências continuam fora deste incremento; o parcelamento existente é anual.

## Seleções e base

Unifica o cargo e a convocação do `NationalCoach` mais recente com a preparação e calendário da 0.5.0: uma fonte de verdade para seleção, lista e confiança, evitando resultados avaliados em dobro. Preserva anúncios/lesões, uniformes e Copa da branch original. Mantém os três torneios extras de base, elegibilidade e minutos, bem como os planos e estilos novos.

Mantêm-se as limitações da 0.5.0: comando internacional por convocação/preparação, sem substituições manuais ao vivo; parte das eliminatórias/torneios ainda é agregada; academias adversárias não são todas individualizadas; calendários pós-2030 são projeções.

## Interface, eventos e aparências

- Numeração com quantidade de colunas calculada pela largura, nomes com quebra e identificação completa, sem grade fixa de dez colunas. Trocas repetidas de camisa não permitem acumular moral artificialmente.
- Ações principais com contraste calculado em normal/hover/pressionado; foco visível. Mantém os ajustes de toque, paisagem/tablet e cache da base.
- Tratamento de clube inexistente e de ausência de carreira em telas de clube/numeração, em vez de desreferenciar um objeto nulo.
- Quatro informes contextuais: desgaste, retorno de lesão, obrigações parceladas e sequência de jovens. Intervalos/cooldowns evitam spam; não criam dinheiro ou atributos instantâneos.
- Oito cabelos e quatro barbas acrescentados ao fim dos catálogos; os índices anteriores foram preservados. Total: 219 cabelos e 145 barbas, com parâmetros e pesos correspondentes.
- Nenhuma proposta de iluminação experimental anterior foi aplicada.

## Dados reais: cobertura efetiva e limites

**NÃO foram licenciados todos os jogadores, clubes ou treinadores. Nenhuma licença comercial foi obtida.** O incremento contém um piloto de **52 jogadores e dois técnicos, de Palmeiras e Barcelona**, com fontes oficiais e data de consulta 29/09/2026. Os outros elencos continuam procedurais ou dependem dos mods existentes. Não são adicionadas fotografias ou imagens de escudos baixadas.

`data/world/real_roster_pilot.json` separa identidade, elenco, camisa, nascimento e altura consultados de **estimativas autorais de simulação**: atributos, overall-alvo, teto de potencial, contratos, salários, valores, pé quando não verificado e aparência. Os parâmetros não são notas oficiais de terceiros. Retratos são procedurais e aproximados, NÃO escaneamentos nem garantia de semelhança fiel. Escudos existentes foram preservados, não uma atualização completa licenciada.

As duas listas são aplicadas somente em novas carreiras padrão, com IDs estáveis e sem duplicar membros da lista. Sobras procedurais tornam-se agentes livres. Um save em andamento não é convertido e edições/mods mantêm precedência. Datas são metadados completos; a idade do motor continua usando ano de nascimento. Não se inventam carreiras passadas ou estatísticas históricas dos nomes reais; a ficha deixa claro que números futuros pertencem à simulação. Eventos de acusação por apostas não são gerados para os jogadores identificados pelo piloto.

Fontes de elenco e técnicos (perfis individuais no JSON):
- https://www.palmeiras.com.br/elenco/
- https://www.palmeiras.com.br/comissao-tecnica/tecnico/
- https://www.fcbarcelona.com/en/football/first-team/players
- https://www.fcbarcelona.com/en/football/first-team/staff/4030694/hansi-flick

A coleta automatizada de Barcelona encontrou respostas HTTP 429 e não as contornou. Os campos básicos restantes foram consultados manualmente nas páginas públicas. Os arquivos de revisão não foram importados cegamente: registros duplicados e extrações inválidas de nomes foram descartados.

## Validação e distribuição

Suítes `depth_bootstrap.gd`, `realism_bootstrap.gd` e `mobile_regression.gd`; importação completa e proibição de exportar se houver erros de script. Capturas de interface usam o Godot com OpenGL/Mesa, não montagens ou imagem gerada por IA. Logs e resultados acompanham o artefato. Testes headless e renderização desktop não substituem Android físico, campanha de anos ou migração de save real.

O APK de avaliação usa pacote separado `com.maisumarodada.futebol.realismtest`, nome `Mais Uma Rodada 0.5.1 Teste`, versão 0.5.1/código 14, arm64. Não desinstalar o original. Ele não acessa automaticamente a carreira do aplicativo anterior. A configuração de produção no repositório continua usando o pacote original.

Não há afirmação de que todos os travamentos ou problemas de memória foram eliminados. Avisos de encerramento do motor/exportador permanecem nos logs. Não há FPS medido em celular/tablet físico nem certificação de fidelidade estatística ao futebol real.
