> Documento histórico. Para a configuração atual 5.5.0, siga `LEIA-ME-MOTOR-DE-ANUNCIOS.md`; a alternância local para Auto Ads in-page descrita em versões anteriores foi retirada.

# Game Overdrive 5.4.1

Atualização de texto dos convites automáticos do canal Games no WhatsApp. Base: versão 5.4.0 entregue nesta conversa. O instalador é completo e não exige aplicar patches.

## Nova prioridade

Todos os textos padrão dos convites de Games passam a destacar **alertas de jogos grátis e promoções**. Guias, análises, códigos, atualizações e notícias aparecem como benefícios complementares, conforme o contexto editorial já resolvido pelo tema.

Convite genérico:

**Quer jogos grátis e boas promoções?**

Receba alertas de jogos grátis e promoções no WhatsApp. Também enviamos guias e notícias.

Em matérias com assunto identificado, a pergunta continua contextual. Por exemplo, um guia pode apresentar “Jogando Wolverine?” e a chamada “Receba alertas de jogos grátis e promoções no WhatsApp, além de guias de Wolverine”. O convite não afirma que Wolverine esteja grátis ou em promoção.

Destino preservado: https://whatsapp.com/channel/0029VbD3xgo5K3zd4n3vhk2r

## Alcance

O produtor automático é `inc/channel-invite.php`. Foram atualizados o fallback genérico, o fallback com assunto e as variações específicas para notícia, review, guia, códigos, beta, atualização, lançamento, jogo grátis e oferta. As perguntas genéricas que destacavam somente códigos, guias ou betas também passam a priorizar jogos grátis e promoções.

O texto mantém as duas linhas existentes, com pergunta e chamada. A localização, os critérios editoriais, a deduplicação, o destino do link e a proteção em relação aos anúncios seguem o comportamento anterior. Tecnologia, Turcas e Entretenimento continuam com seus próprios convites. A atualização não reescreve blocos de texto salvos manualmente pela redação no banco de dados nem altera overrides de plugins.

O código de monetização, seu runtime e as configurações de conta não foram modificados nesta atualização. Os documentos 5.4.0 descrevem a auditoria e a arquitetura de base; este guia descreve a mudança posterior de texto.

## Instalação

1. Guarde o ZIP anterior.
2. Em Aparência → Temas → Adicionar novo → Enviar tema, instale **news-magazine-x-5.4.1-cta-games.zip** e substitua a versão do mesmo tema.
3. Limpe o cache de páginas/CDN para que matérias já cacheadas passem a exibir os novos textos.
4. Confira uma notícia e um guia de Games, além de uma matéria de Tecnologia. A versão pública do tema passa a ser 5.4.1.

Nenhuma implantação no site foi executada nesta entrega. Para voltar, reinstale a 5.4.0 e limpe os mesmos caches. Esta atualização não migra opções nem conteúdo do banco.

## Validação desta atualização

- Integração existente do componente de canais: **82 asserções aprovadas**.
- Verificações estáticas: **109 asserções aprovadas**.
- Lint dos três arquivos PHP alterados: **3/3**.
- Conferência do ZIP contra todos os arquivos finais e comparação com a base para delimitar a mudança.
- Sem chamadas de anúncio ou alteração de conta durante a validação.

Os testes acima são os executados para esta atualização. A matriz completa da auditoria 5.4.0 é histórica; não foi contada como uma nova execução na 5.4.1. Não há afirmação de aumento medido de seguidores ou receita decorrente da mudança de texto.
