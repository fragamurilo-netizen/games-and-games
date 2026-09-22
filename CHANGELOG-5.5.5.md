# Overdrive 5.5.5

Base: 5.5.4. Mesmo inventário, mesmas unidades, mesmo runtime
(`12.7.0-context-paint-gate`). Nada de entrega mudou.

Sobe a versão porque o pacote 5.5.4 já tinha sido distribuído e este tem
conteúdo diferente. Dois ZIPs com o mesmo número é como se instala uma correção
e não se vê mudança nenhuma.

## Fecha a armadilha entre servidor consertado e tema recusando

A verificação **Entrega de imagens AVIF** dizia apenas "está certo" quando o
servidor passava a responder `image/avif`, e parava ali — enquanto o tema
continua tratando AVIF como formato indeliverable, porque
`go_verge_allow_avif_uploads` é falso por padrão. E com razão: o padrão foi
escrito para um servidor quebrado.

A armadilha: o operador conserta o `.htaccess`, vê verde no painel, e nada muda.
`og:image` continua vazio, `Article.image` continua sem AVIF e o acervo continua
inelegível, por uma decisão do tema que ninguém mandou revisar.

Agora, enquanto os dois discordarem, a verificação não é "boa": é pendência, com
o passo exato — a linha de `wp-config.php` que reabre upload, `og:image`, imagem
de schema e prontidão do Discover de uma vez só.

## O passo a passo que o painel mandava ler e não existia

`inc/discover-cwv.php` apontava para `docs/servidor-mime-avif.md`. O arquivo
nunca foi escrito. Está escrito: confirmar o sintoma, corrigir, verificar,
o que fazer quando `.htaccess` não resolve (nginx, `AllowOverride`), e o acervo
antigo que a correção de MIME não conserta sozinha.

## Ferramenta de diagnóstico de receita

`deployment/diagnostico-receita.js`, para colar no console numa matéria
publicada. Distingue as cinco causas de "poucas impressões" — motor que não
carregou, planner que não criou a posição, posição que não pediu, pedido que o
Google não preencheu, criativo que ninguém viu — porque elas pedem correções
opostas e subir densidade só conserta uma delas.

Somente leitura: não pede anúncio, não altera DOM, não guarda nem envia nada.

## Validação

Suíte completa sem falhas. `php -l` limpo em todos os arquivos do pacote.
