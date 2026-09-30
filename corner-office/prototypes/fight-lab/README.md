# Fight Studio

Laboratório visual ligado ao motor de combate Godot. Na pasta `corner-office`:

```sh
godot --headless --path game --editor --import
python tools/fight_lab_server.py --godot /caminho/absoluto/godot --port 8768
# http://127.0.0.1:8768/prototypes/fight-lab/
```

Escolha dois atletas, organização, rounds, plano e seed; clique **Simular confronto**.
A luta é autônoma. O mesmo motor gera o resultado e o registro que o player reproduz.
Há KO/TKO, quinze técnicas de submissão, dano regional, fadiga e cartões dos juízes.
O plano muda preferências táticas, preservando os atributos originais do atleta.

Sem Godot, `python -m http.server 8767 --bind 127.0.0.1` permite assistir aos quatro
replays reais pré-calculados e às seis demonstrações autorais. Não gera novas lutas.

- 158 técnicas, 486 respostas pareadas, dez bases e sete arenas fictícias.
- Reprodução, pausa, seek, 0,25×/1×/2×/5× e resultado instantâneo.
- Rostos compartilhados com Face Lab; materiais anatômicos, membros conectados,
  recuperação da guarda, bruising regional e cortes discretos.
- Exportação/importação do registro completo; a velocidade não altera o vencedor.
- O render é 2D paramétrico. Contato fino, oclusão e rotações de chão ainda precisam
  de refinamento artístico; o renderer nativo Godot permanece no roadmap.

[Contrato, testes e passagem de trabalho](../../docs/FIGHT_VISUALS.md).
[Pesquisa em relatos oficiais de lutas reais](../../docs/FIGHT_BEHAVIOR_RESEARCH.md).
