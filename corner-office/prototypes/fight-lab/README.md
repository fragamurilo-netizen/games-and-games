# Fight Studio

Laboratório de movimentos, interações e arenas do Corner Office. Execute um
servidor na pasta `corner-office` e abra `/prototypes/fight-lab/`.

```sh
python -m http.server 8767 --bind 127.0.0.1
```

Catálogo procedural 2D com 156 técnicas, 478 respostas pareadas, dez bases,
sete arenas e seis replays autorais. O player só ilustra eventos resolvidos.
Use filtros para encontrar uma técnica e inspecione suas respostas; importar
JSON permite testar o contrato destinado ao futuro FightEngine.

- Play/pause, seek, 0,25×, 1×, 2×, 5× e resultado instantâneo.
- Câmeras de transmissão, detalhe e arena; visualização opcional do rig.
- Rostos compartilhados com face-lab, atletas masculinos e femininos.
- Cages das seis organizações e ringue da Shinsei.
- Exportação do registro JSON; nenhuma ação controla golpes de uma partida.

O protótipo usa poses 2D paramétricas, sem física de colisão ou motion capture.
O renderer nativo na Godot e o motor de combate ainda precisam ser ligados.

[Contrato, testes e passagem de trabalho](../../docs/FIGHT_VISUALS.md).
