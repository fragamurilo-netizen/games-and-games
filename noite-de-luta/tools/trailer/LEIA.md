# Trailer

1. Grave as duas partes com `tools/trailer_runner.gd` (comando no topo do arquivo). O Movie Maker usa o tamanho de janela do projeto: para gravar em 780x1688, crie um `override.cfg` local (fora do git) com `window/size/window_width_override=780` e `window_height_override=1688` em `[display]`, e apague depois.
2. Ponha `a.avi`, `a.log`, `b.avi`, `b.log` numa pasta `hd/` ao lado destes scripts.
3. `python3 trilha.py trilha.wav 53` (trilha sintetizada, sem direitos de terceiros), `python3 cartelas.py cart`, `python3 monta.py trailer.mp4`.

## Versão do Reddit (4:5, 1080x1350, 31 s)

Depois de gravar as duas partes como acima, numa pasta com `hd/`: `python3 cartelas_reddit.py PASTA/cart` (`TR_LANG=en` para os letreiros em inglês), `TR_DROP=1.2 TR_SWITCH=17.4 TR_END=27.6 python3 trilha.py PASTA/trilha.wav 31.4`, `python3 monta_reddit.py PASTA saida.mp4`. Os cortes e enquadramentos estão na lista `SEG` de `monta_reddit.py`.
