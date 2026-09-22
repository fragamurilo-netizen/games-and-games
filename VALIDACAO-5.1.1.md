# Validação da versão única 5.1.1

Resultado final: **33 suítes aprovadas**, com 23 suítes PHP e dez JavaScript. As verificações são de qualidade de software em ambiente local; nenhuma variante foi distribuída a leitores.

| Verificação | Resultado |
|---|---|
| Sintaxe PHP do pacote final | 257/257 arquivos passaram |
| Integridade estática final | 109/109 asserções |
| Top Scroll: migração, reexecução, overrides e HTML administrativo | 72/72 asserções |
| Top Scroll: default explicitamente sobrescrito | 6/6 asserções |
| Loader canônico | 17 verificações PHP e oito cenários JavaScript |
| Continuidade de listagens/hubs | 18 cenários, 216 asserções |
| Política única do runtime | 15 cenários na fonte e no minificado |
| Regressões anteriores do runtime | Nove cenários na fonte e no minificado |
| Agregação SQL | 14 verificações |
| Reconstrução do minificado | Idêntica byte a byte |
| Arquivos e hooks A/B da 5.1.0 | Removidos do pacote e da execução |
| Requisições publicitárias reais na automação | Zero |
| Páginas executadas em navegador real | Zero |

## Escopo observado

Os cenários cobrem mobile/desktop, reservas alcançadas/iminentes/frias, capacidade estrutural, densidade, consentimento negado/tardio, armazenamento negado, aba em segundo plano, preenchimento/vazio/resposta tardia, loader único, duplicação, conteúdo dinâmico, hero real, paginação e quotas locais do Top Scroll.

A política única funciona sem o bootstrap antigo, sem canais e sem permissão de medição experimental. O consentimento publicitário aplicável e a autorização para armazenamento continuam separados e respeitados. O getter da antiga infraestrutura pode lançar erro nos stubs sem ser lido pelo novo runtime.

A primeira rodada integrada terminou com 32 de 33 suítes aprovadas porque três arquivos antigos A/B ainda estavam fisicamente presentes na cópia compartilhada. O comportamento de produção já não os carregava. Os arquivos foram excluídos no ambiente que empacota o ZIP e a guarda foi repetida, passando 109/109. O histórico da falha foi preservado.

O ajuste final da interface Top Scroll para identificar e respeitar a constante legada teve validação dirigida de HTML e lint. Não foi repetida a matriz inteira após alterações que não afetavam seus outros caminhos. O inventário e os hashes finais refletem a versão entregue.

## Limites

PHP local 8.3.6; o snapshot publicado informa 8.5.4. O SQL foi exercitado em SQLite, não no banco de produção. DOM/provedor de anúncios são simulados. O ambiente não permitiu iniciar navegador real; por isso não foi alegada validação visual de criativos, CWV de campo ou receita adicional.

Os registros detalhados ficam em `docs/validacao-5.1.1/`. O ZIP foi verificado quanto a integridade, nomes únicos, raiz WordPress correta e equivalência dos bytes extraídos com a árvore final. O tema original e a 5.1.0 foram preservados fora deste pacote. Nenhuma implantação ou alteração da conta AdSense foi executada.
