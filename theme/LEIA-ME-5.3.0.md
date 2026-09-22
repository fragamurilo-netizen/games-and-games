# Game Overdrive 5.3.0

## Versão única para instalar

Este é o pacote completo do tema. Ele reúne as correções da auditoria, a política manual única e a revisão final de monetização, publicação e CTA de Tecnologia. Não exige instalar versões intermediárias, criar unidades AdSense ou distribuir visitantes em grupos.

- Tema: **5.3.0**.
- Runtime: **12.5.0-delivery-integrity**.
- Publisher: **ca-pub-3687004010207904**.
- Arquitetura: anúncios manuais no fluxo, com loader e âncora/vinheta oficiais preservados.
- Canal Tech: **https://whatsapp.com/channel/0029Vb8lV4nFi8xiDKv2mT08**.

## Instalação

1. Faça o backup normal do WordPress, banco e opções do tema. Guarde o instalador anterior.
2. Em Aparência → Temas → Adicionar novo → Enviar tema, envie `news-magazine-x-5.3.0-final.zip` e substitua a versão instalada do mesmo tema.
3. Invalide o cache do HTML e dos assets no cache/CDN utilizado. O HTML antigo pode continuar apontando para o runtime anterior mesmo depois da troca dos arquivos.
4. Confirme a versão 5.3.0 no tema e `12.5.0-delivery-integrity` em `GOAdsRuntime.inspect()`, numa página com JavaScript executado.
5. Confirme uma matéria curta, uma longa, uma de Tecnologia e uma listagem nos layouts mobile e desktop. O criativo real depende do AdSense; a ausência de um anúncio isolado não prova erro de execução.

O pacote não altera o painel AdSense. Nesse painel, a configuração pretendida continua sendo âncora e vinheta ligadas e anúncios automáticos in-page desligados, com os controles de posições adicionais/otimização alinhados à distribuição manual. Preserve o loader e o recurso geral necessário aos formatos oficiais.

## O que a revisão final corrige

### Monetização e tempo de entrega

Uma revisão negativa do relatório não pode ser reinterpretada como preço atual utilizável, mesmo quando não há novos pageviews/impressões ou quando falta um ponto inicial de coleta. As diferenças permanecem assinadas para diagnóstico; os controles ficam neutros quando o sinal é inválido.

A hora do dia deixa de impor requisitos adicionais de engajamento e menor antecipação sem uma curva horária comprovada. Os horários usam a mesma base já aplicada durante o dia, respeitando os mínimos por dispositivo. Isso não afirma que a demanda do Google seja constante durante o dia.

Sugestões oficiais em unidades sem preenchimento não fortalecem o sinal local de anúncios preenchidos. Uma janela antiga e distante que excedeu o limite após resize não veta outra posição que não a modifica. A materialização de um host provoca uma reconciliação coalescida da geometria para que posições seguintes não esperem uma resposta silenciosa de outro anúncio.

O painel distingue receita estimada acumulada, diferenças de estimativas e revisões. Ele não apresenta sensibilidade de RPM como dinheiro recuperável nem `floor_scale` como preço mínimo do leilão.

### Publicação e sitemaps

Os candidatos dos sitemaps News/Fresh passam a considerar a primeira publicação pública registrada, inclusive quando um post preparado/agendado é publicado mantendo datas antigas do WordPress. A validação final de janela, privacidade e indexabilidade permanece. Alterações relevantes de senha, data, autor e primeira publicação invalidam os caches pertinentes.

Nenhuma data editorial é rejuvenescida e nenhum permalink é reescrito. A correção ajuda a publicar sinais coerentes; não é uma garantia de indexação ou distribuição no Discover.

### Melhorias acumuladas preservadas

- Reservas do corpo já alcançadas podem usar capacidade estrutural válida, passando pelos controles locais.
- F4/F5 continuam até os cards adicionados de verdade, sem reiniciar o pool nem repetir IDs.
- O carregamento considera distância, velocidade e latência observada; memória de sessão respeita consentimento.
- Full width permitido não é anulado pelo seletor específico do corpo. Sticky incompatível com a altura útil volta ao fluxo, sem ocultar o criativo.
- Top Scroll mantém até seis preenchimentos locais em janela móvel de 24 horas; quinto/sexto exigem os critérios adicionais descritos no manual do motor.
- CTA Tech adapta a chamada à editoria/subeditoria ou assunto estruturado, preserva convites editoriais e evita duplicação.
- GOAC, Ads Center e integrações úteis de relatório continuam integrados.

## Operação e disponibilidade

O tema não corrige sozinho quedas da hospedagem, limites de CPU/processos, regras de CDN ou desafios de bot. Se houver indisponibilidade, correlacione logs de acesso/erro, PHP e recursos com os horários reais. Diferencie acesso do visitante, do Googlebot verificado e da ferramenta de auditoria. Não desative globalmente a proteção nem libere um user-agent apenas pelo nome.

Não há rotina nova de coleta publicitária real, refresh, cron adicional ou envio externo de dados nesta revisão. Os sitemaps trabalham com consultas limitadas e cache; sua reconstrução e o diagnóstico administrativo explícito não são parte do carregamento normal de cada matéria.

## Acompanhamento da versão única

Registre o horário da instalação e use os relatórios normais. Nas primeiras 24–48 horas, procure erros, regressões de entrega, cache misto, falhas de consentimento e conflitos visuais. Nas revisões de sete e 14 dias, recalcule RPM pelos totais e acompanhe receita, impressões por página, cobertura, valor por impressão e audiência. Comparações antes/depois continuam sujeitas a alterações de tráfego e demanda.

O diagnóstico próprio descreve execução/exposição local. Ele não comprova receita nem substitui Active View. Os relatórios AdSense são estimativas sujeitas a atraso e revisão; queda da média acumulada pode coexistir com aumento do dinheiro recebido no intervalo.

## Reversão

Reinstale o tema anterior e invalide os mesmos caches. Uma reversão de arquivos não desfaz opções persistidas: para desfazer a migração legada do Top Scroll, restaure também o valor registrado no backup. A atualização não redefine escolhas explícitas posteriores nem altera controles da conta Google.

Detalhes: `LEIA-ME-MOTOR-DE-ANUNCIOS.md`, `CHANGELOG-5.3.0.md` e `VALIDACAO-5.3.0.md`. Os dados privados e a análise econômica são fornecidos separadamente, fora do instalador.
