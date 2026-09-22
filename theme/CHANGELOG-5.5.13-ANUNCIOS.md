# Overdrive 5.5.13 — entrega dos anúncios manuais

## Correção principal

A7 e A8 estavam configurados com IDs, mas a seleção, a reserva de identidades e a composição ainda limitavam a escada a A6. A função que calculava capacidade declarava até nove posições; o HTML não conseguia entregá-las. Os testes anteriores verificavam a capacidade numérica, sem exigir a emissão da última unidade.

Agora a seleção e os alvos de profundidade acompanham a escada contígua configurada. O compositor aceita as posições e reconhece HTML já composto, inclusive acima de A6. Matérias longas com estrutura suficiente podem expor P1 + A1–A8. IDs ausentes/desabilitados interrompem a escada; não há criação de IDs, refresh nem repetição de unidade.

## Carregamento e geometria

- Reservas próximas abaixo da tela podem preparar após engajamento, dentro de meia viewport útil e do limite de antecipação do tier. Não exige velocidade de rolagem quando o leitor pausa. Consentimento, visibilidade, densidade e capacidade estrutural continuam obrigatórios.
- O perfil mobile/desktop acompanha a largura atual, inclusive em uma varredura após restauração de página. Não recria anúncios já solicitados.
- Loader canônico permanece único e assíncrono, com atributos de exclusão de otimização. A configuração GOAdsYieldConfig e arquivos de recuperação também entram nas exclusões LiteSpeed.
- Runtime `12.8.0-near-reader`; planner `19.1.0-contract-ladder`. Fonte, minificado e cópia pública enxuta regenerados juntos.

Os limites de densidade seguem 3 unidades por janela, parcela local de 45% mobile / 42% desktop, relação global de 45% no corpo e espaçamento base de 240/300 px. Esses limites internos não são uma certificação de conformidade pelo Google.

## Evidências de validação

- Antes da correção, o novo teste de integração falhou: esperado 9, recebido 7; última unidade ausente do HTML. Depois, o mesmo cenário emitiu 9, sem duplicação.
- 60 suítes PHP/JavaScript passaram, incluindo 5.000 layouts, 1.000 geometrias de densidade, 1.200 sessões e casos de consentimento/loader único/recuperação do runtime.
- 283 arquivos PHP passaram na validação de sintaxe; 17 casos adicionais de recuperação do loader/runtime passaram em jsdom, incluindo consentimento tardio e disputa entre inicialização normal e recuperação.
- Novo teste de reservas próximas e troca de perfil passou na fonte e no minificado. Paridade da cópia pública enxuta passou na suíte completa.
- Chromium: HTML produzido pelo planner/compositor reais, CSS e runtime locais, com provedor simulado. Nas larguras 390 e 1440 px, leitura completa solicitou nove IDs distintos; sem overflow horizontal; redimensionar não repetiu pedidos. Capturas em `output/playwright/`, fora do ZIP de instalação.
- A suíte de escada tinha uma chamada de subprocesso incompatível com Windows; agora passa a variável de ambiente via PHP e restaura seu estado depois.
- Consulta pública em 22/09/2026: homepage com um loader canônico; `ads.txt` HTTP 200 contendo `google.com, pub-3687004010207904, DIRECT, f08c47fec0942fa0`. Isso não verifica restrições ou configurações privadas da conta AdSense.

Simulações validam lógica e layout; não medem preenchimento real, Active View, leilão ou receita. Nenhuma configuração da conta ou instalação de produção foi alterada nesta auditoria.

## Instalação e conferência

1. Guardar o tema anterior e backup das opções/banco. Enviar `news-magazine-x-5.5.13-anuncios.zip` como atualização do tema Overdrive em Aparência → Temas.
2. Limpar caches de página, CDN/LiteSpeed e assets: o runtime é inline, portanto só limpar JS não basta.
3. Confirmar tema 5.5.13 e `GOAdsRuntime.inspect().version === '12.8.0-near-reader'`. Em matéria longa elegível, conferir `data-go-ad-plan-planner-version="19.1.0-contract-ladder"` e A7/A8 no HTML. Não precisam solicitar antes de serem alcançados.
4. No AdSense, conferir âncora/vinheta oficiais e a arquitetura manual descrita no manual. O tema não muda esses seletores nem resolve bloqueios, restrições ou baixa demanda da conta.
5. Comparar horários equivalentes e dias fechados, separando mobile/desktop, origem de tráfego, tamanho de matéria e unidade: receita, Page RPM, impressões/PV, RPM de impressão, cobertura e Active View. Não somar ou tirar média simples dos RPMs: calcular por totais.

Com os dados informados, agosto teve 8,37 e 8,12 impressões/PV; hoje, 5,10. Mantendo US$ 0,49 por mil impressões, 6,2 impressões/PV corresponderiam a aproximadamente US$ 3,04 de Page RPM. É uma conta de sensibilidade, não uma previsão: ampliar oferta também pode mudar preço, cobertura e visibilidade. A correção de A7/A8 beneficia sobretudo leitores que chegam a posições adicionais; o efeito global depende da participação dessas visitas.

Para reversão, restaurar o pacote anterior e limpar os mesmos caches. Esta atualização não migra opções, não altera frequência do Top Scroll e não ativa testes por calendário.

Referências: [posicionamento de anúncios](https://support.google.com/adsense/answer/1282097?hl=pt-BR), [visibilidade](https://support.google.com/adsense/answer/6219980?hl=en), [tag assíncrona](https://developers.google.com/publisher-ads-audits/reference/audits/async-ad-tags).
