# Trailer

1. Grave as duas partes com `tools/trailer_runner.gd` (comando no topo do arquivo). O Movie Maker usa o tamanho de janela do projeto: para gravar em 780x1688, crie um `override.cfg` local (fora do git) com `window/size/window_width_override=780` e `window_height_override=1688` em `[display]`, e apague depois.
2. Ponha `a.avi`, `a.log`, `b.avi`, `b.log` numa pasta `hd/` ao lado destes scripts.
3. `python3 trilha.py trilha.wav 53` (trilha sintetizada, sem direitos de terceiros), `python3 cartelas.py cart`, `python3 monta.py trailer.mp4`.
