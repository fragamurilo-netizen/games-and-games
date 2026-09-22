# Game Overdrive 5.5.9 — Site Health AVIF

## Correção

O teste `Entrega de imagens AVIF` estava registrado em `site_status_tests` como
assíncrono, mas o campo `test` apontava diretamente para uma função PHP. O
WordPress espera, para testes assíncronos, uma action de `admin-ajax.php` ou uma
URL REST. Resultado: os demais testes do módulo apareciam, mas o diagnóstico
específico de AVIF sumia da tela de Saúde do Site.

A 5.5.9 registra esse diagnóstico como teste direto. A sonda HTTP continua sendo
executada apenas quando a própria tela de Saúde do Site roda, sem custo nas
páginas públicas.

O resultado passa a distinguir:

- AVIF público ainda não chega como `image/avif`;
- MIME já está correto, mas GD/Imagick não processa AVIF para gerar derivados;
- MIME + editor AVIF estão corretos e novos uploads podem ser liberados.
