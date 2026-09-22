# Game Overdrive 5.5.8 — recuperação AVIF / Discover

## Problema corrigido

O servidor podia estar corretamente configurado para responder `.avif` como
`image/avif` e, mesmo assim, o tema continuava tratando AVIF como quebrado porque
`go_verge_allow_avif_uploads` tinha `false` como estado padrão permanente.

Isso criava uma contradição: a infraestrutura já estava corrigida, mas upload,
`Article.image` e o diagnóstico do Discover continuavam presos ao estado antigo.

## O que mudou

- `inc/image-deliverability.php`
  - adiciona uma sonda AVIF HTTP real e cacheada;
  - testa `HEAD` e faz fallback para `GET Range`;
  - usa um AVIF minúsculo incluído no próprio tema quando ainda não existe uma
    imagem AVIF recente na biblioteca;
  - aceita AVIF em schema/Discover automaticamente quando a resposta pública é
    `200/206` + `Content-Type: image/avif`;
  - mantém SVG, JXL, HEIC/HEIF e TIFF fora das imagens representativas;
  - separa **entrega HTTP** de **capacidade de processar novos uploads**.

- `functions.php`
  - o upload AVIF deixa de depender de um filtro manual em `wp-config.php`;
  - novos AVIFs são liberados automaticamente somente quando o MIME público está
    correto **e** o editor de imagens do WordPress suporta AVIF;
  - quando liberado, o MIME `avif => image/avif` é explicitado;
  - a mensagem de erro agora diz se a falha é MIME HTTP ou falta de suporte no
    GD/Imagick.

- `inc/discover-cwv.php`
  - o Site Health não responde mais "nada a verificar" quando não há AVIF
    recente;
  - passa a testar o arquivo AVIF de sonda do tema e, quando houver, uma imagem
    AVIF real da biblioteca;
  - distingue servidor corrigido de editor de imagens ainda incompatível.

- `tests/test-discover-image-deliverability.php`
  - inclui cobertura para reabertura automática via resultado do probe;
  - mantém o filtro antigo apenas como override emergencial compatível.

## Servidor

A correção de servidor continua necessária e deve ficar fora de `# BEGIN
WordPress`. O bloco já usado no Game Overdrive é suficiente quando a resposta
pública realmente mostra `Content-Type: image/avif`:

```apache
AddType image/avif .avif

<FilesMatch "\.avif$">
    ForceType image/avif
</FilesMatch>

<IfModule mod_headers.c>
    <FilesMatch "\.avif$">
        Header set Content-Type "image/avif"
    </FilesMatch>
</IfModule>
```

Depois de alterar `.htaccess`, limpe LiteSpeed/CDN para não validar um cabeçalho
antigo em cache.

## Importante

Não é necessário colocar `add_filter()` no `wp-config.php`. O `wp-config.php` é
carregado antes de a API de hooks estar garantidamente disponível e não é o
lugar correto para registrar esse filtro.

Nenhum tema pode garantir distribuição no Google Discover. Esta versão remove o
bloqueio técnico de entrega/representação da imagem e deixa os sinais internos
coerentes com a resposta real do servidor.
