# Fatal Frame — especial para o Game Overdrive

Versão 2.0.0 · 19/09/2026

## Instalação

1. Envie `fatal-frame-specials.zip` para a pasta `wp-content/themes/news-magazine-x/specials/`, a mesma da captura enviada.
2. Extraia o ZIP nessa pasta. Ele já contém a pasta `fatal-frame`. Confira este caminho:
   `wp-content/themes/news-magazine-x/specials/fatal-frame/manifest.json`
3. No WordPress, abra o post que vai receber o especial. Na caixa **Layout Especial**, selecione **Estado: Usar Especial** e **Design: Fatal Frame: a história da franquia**.
4. Salve o rascunho e use **Visualizar** para conferir antes de publicar.

O tema descobre o especial pelo manifest.json. Não é necessário colar código no editor ou substituir arquivos do tema. O conteúdo é carregado de content.html; título, permalink, autoria, imagem destacada e campos de SEO continuam sendo configurados no post.

## O que está incluído

- 17 imagens oficiais em WebP, armazenadas em assets, com créditos no artigo.
- Fontes locais, sem dependência do Google Fonts.
- Linha do tempo navegável entre os jogos, com suporte a teclado.
- Galeria ampliável, com setas, legendas e fechamento por Esc.
- Navegação por capítulos, progresso de leitura e escolha de percurso para começar a série.
- Layout adaptado para celular e computador.

As imagens são servidas pelo próprio site. Os caminhos seguem o nome de pasta do tema mostrado na captura: news-magazine-x. Se o tema for renomeado, ajuste esse segmento em content.html. Mantenha os arquivos de assets junto dos demais arquivos do especial.

## Arquivos

manifest.json: cadastro no seletor do tema.
content.html: conteúdo e imagens, usando os tokens do tema.
style.css: estilos restritos ao especial.
script.js: interações, sem bibliotecas externas.
assets/: imagens e fontes.
creditos-imagens.json: URLs de origem e dimensões das imagens.
EDITORIAL-SEO.md: sugestões de título, descrição e imagem destacada.

Para trocar texto, edite content.html. Para mudar uma imagem, preserve seu nome em assets ou atualize sua referência no conteúdo.

## Se o especial não aparecer

Confira se o ZIP não foi extraído com uma pasta duplicada: specials/fatal-frame/fatal-frame está errado. O manifest.json precisa estar diretamente em specials/fatal-frame. Após selecionar o layout, salve o post. Se a visualização ainda mostrar a versão antiga, limpe o cache da página.

## Verificação

Pacote montado conforme o carregador de especiais do arquivo news-magazine-x fornecido anteriormente. Imagens, scripts e estilos foram testados em servidor local reproduzindo os caminhos e a substituição de tokens do tema. Navegação, galeria e larguras de 320, 390, 768 e 1440 px foram conferidas. A instalação no servidor de produção não foi realizada.
