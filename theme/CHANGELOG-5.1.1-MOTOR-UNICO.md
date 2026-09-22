# 5.1.1 | Motor manual único

Versão preparada a pedido do usuário para uso sem experimentos. Base 5.1.0, preservando o original 37. Runtime 12.3.0-unified-manual.

## Alterações

- Reserva estrutural alcançada ou imediatamente próxima passa a ser política normal, sem grupo de controle/tratamento e sem depender de matrícula em outra navegação.
- Removidos módulo PHP, interface administrativa, bootstrap JavaScript, loader alternativo, canais e eventos GA4 próprios do experimento da 5.1.0.
- Preservados o loader oficial único, anúncios manuais, âncora e vinheta oficiais, consentimento aplicável e integrações úteis de relatório.
- Top Scroll usa o preset até6/24h, com quatro exibições normais e quinta/sexta condicionadas ao engajamento. Migração única dos valores legados três/quatro, respeitando desabilitação e overrides explícitos. Preferências posteriores não são regravadas a cada acesso.
- Continuidade F4/F5 permanece normal. O hook de hubs após hero passa a integrar a distribuição normal, somente na fronteira real e primeira página efetiva, com deduplicação.
- Mantidos memória consentida de latência, prioridade por geometria atual, tratamento neutro de revisões/atrasos financeiros e correções anteriores de runtime e diagnóstico.
- Atualizados os documentos e verificadores para a versão única. As simulações de qualidade continuam sendo verificações de software, não experimentos com visitantes.

Não há canal a criar, percentual de público a escolher, data de teste a definir ou melhoria que precise ser liberada em uma tela experimental. Os slots existentes já estão configurados.

## Instalação e reversão

Enviar o ZIP completo pelo WordPress e substituir o mesmo tema; invalidar cache de páginas/assets. Não é preciso instalar versão intermediária. O pacote não foi implantado pelo assistente.

Rollback por tema anterior e cache; a frequência Top Scroll é persistida e deve ser restaurada pela opção/backup se também for desejado reverter esse preset. Consulte LEIA-ME-MOTOR-DE-ANUNCIOS.md e VALIDACAO-5.1.1.md.
