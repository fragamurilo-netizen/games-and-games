# Game Overdrive 5.2.0

## Pacote único pronto para instalação

Esta versão reúne o motor manual da 5.1.1, correções de geometria dos anúncios, consistência dos sinais editoriais e de descoberta e o convite contextual para o canal de Tecnologia.

O publisher e as unidades AdSense existentes continuam configurados. Não há novos IDs a criar, divisão de visitantes, canal de experimento ou recurso a ativar para essas correções funcionarem.

## Instalação

1. Preserve o ZIP anterior e um backup normal do WordPress e do banco de dados.
2. Envie este ZIP por **Aparência → Temas → Adicionar novo → Enviar tema**. Quando o WordPress reconhecer o mesmo tema, use a substituição da versão instalada. Pode atualizar diretamente para 5.2.0.
3. Limpe o cache de páginas e assets no WordPress e no CDN utilizado. O tema já solicita uma purga LiteSpeed por versão, mas isso não comprova a invalidação de todos os caches externos.
4. Confirme **5.2.0** na versão do tema. O motor emitido nesta versão identifica-se como **12.4.0-responsive-geometry**. Documentos HTML antigos em cache ainda podem carregar regras anteriores.

O pacote foi preparado e validado localmente. Esta entrega não instala o tema, não altera controles da conta Google e não envia URLs/sitemaps para indexação.

## Anúncios

O modelo é **anúncios manuais dentro das páginas + âncora oficial + vinheta oficial**. O loader oficial único e as integrações úteis de relatórios são preservados. A configuração da conta deve manter esses formatos oficiais e a distribuição manual pretendida. O tema não controla os seletores de Auto Ads no painel do AdSense.

As unidades responsivas do corpo deixam de herdar uma restrição CSS que contrariava a expansão já permitida ao Google. A lateral de jogos não oculta um anúncio solicitado ao sair da largura desktop. O runtime espera dimensões válidas antes de pedir o anúncio e verifica se a lateral sticky cabe integralmente na área útil; quando não cabe, o anúncio permanece no fluxo da página. A lateral de jogos com barra local de navegação também usa fluxo normal para evitar conflito. Nenhum desses caminhos faz refresh, recorta o criativo ou altera os iframes oficiais.

A política única de reservas alcançadas, a continuidade F4/F5, a memória consentida de latência, a recuperação após consentimento tardio e o Top Scroll até seis preenchimentos locais/24h continuam disponíveis. Detalhes em **LEIA-ME-MOTOR-DE-ANUNCIOS.md**.

Melhor espaço de renderização e exposição podem favorecer a entrega. O código não define o lance do anunciante nem um preço mínimo e não garante um RPM específico.

## Descoberta e metadados

As correções alinham as datas emitidas pelo Rank Math ao relógio editorial já usado pela matéria, preservam canonicals distintos válidos e corrigem elegibilidade, títulos e expiração do News Sitemap. O Fresh utiliza validação HTTP coerente com sua janela móvel. O RSS aceita variações válidas de aspas/espaços nos atributos. Os diagnósticos respeitam o provider SEO ativo e distinguem regras robots específicas de um bloqueio global.

O tema preserva publicação original, imagem editorial grande, canonical e permissões de prévia. Não redata textos para simular novidade nem transforma requisição ao hub/sitemap em confirmação de indexação. Conteúdo indexado pode ser elegível ao Discover; a seleção pelo Google e o retorno da audiência não são garantidos pelo pacote.

## Canal de Tecnologia

Destino incorporado: **https://whatsapp.com/channel/0029Vb8lV4nFi8xiDKv2mT08**.

O convite existente no corpo adapta sua chamada a celulares, IA, Windows, PCs, TVs/monitores, áudio, wearables, apps/software, ciência ou Tecnologia em geral. A classificação usa a editoria atribuída, subeditorias e assunto estruturado. Uma referência incidental a Android em um texto de Games não altera seu canal.

Existe um único convite por conteúdo. O compartilhamento da matéria e convites explicitamente escritos pela redação são preservados. A nova chamada é um link normal em fluxo, sem popup, novo carregamento externo ou nova coleta automática de eventos.

## Validação e acompanhamento

Consulte **VALIDACAO-5.2.0.md** e **CHANGELOG-5.2.0.md**. As verificações locais usam dublês de WordPress, navegador e provedor quando necessário; nenhuma requisição publicitária real é realizada. Elas comprovam os comportamentos descritos nos cenários, não receita, Active View oficial ou desempenho de campo.

Depois da instalação, use os relatórios habituais para acompanhar receita total, receita por sessão com denominadores conciliados, impressões por página, RPM de impressão, cobertura e visibilidade. Para Discover, acompanhe primeiro a volta de impressões sustentadas por várias URLs, depois cliques e audiência. Registre o horário da implantação e dos problemas de disponibilidade. Isso é acompanhamento de uma versão única, sem divisão de público.

## Reversão

Reinstale o ZIP anterior e limpe os mesmos caches. As correções desta etapa não fazem uma migração de datas, conteúdo ou permalinks. A migração de frequência do Top Scroll já integrada na 5.1.1 continua persistente: reverter arquivos não restaura automaticamente o valor antigo salvo no banco. Preserve a opção no backup se precisar desse rollback.
