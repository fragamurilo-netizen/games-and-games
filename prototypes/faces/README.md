# Laboratório 2D de personagens — PARALELO

Ateliê vetorial independente para experimentar personagens do jogo. Usa formas
e curvas, cores discretas e a mesma identidade no retrato e no corpo inteiro.
Não depende de imagens, fontes externas, bibliotecas instaladas ou 3D.

## Abrir

Abra `index.html` no navegador, ou sirva esta pasta:

```sh
cd prototypes/faces
python -m http.server 8765 --bind 127.0.0.1
```

Ateliê: `http://127.0.0.1:8765/`.
Folha de revisão de corpos, pesos, idades e roupas:
`http://127.0.0.1:8765/body-studies.html`.

## Recursos

- 133 receitas de cabelo, incluindo cortes, comprimentos, texturas e penteados.
- 106 opções de barba e bigode, incluindo barbeado, sombra e variações de comprimento.
- 19 conjuntos de roupa: camisetas, polos, camisas, jaquetas, cardigãs, blazer,
  tricô, moletom, blusas, regata, bermuda, saia, vestidos e túnica.
- Corpo com proporções por idade, sexo, altura, constituição, musculatura e traços herdados.
- Uma calça contínua da cintura às pernas, sem uma peça adicional desenhada sobre as coxas.
- Cabelo atrás e à frente do corpo; mangas e punhos usam os mesmos pontos dos braços.
- Vida de 0 a 110 anos, cabelos grisalhos, calvície, expressões e cinco armações de óculos.
- Pais e filhos selecionáveis, formação de novas gerações e origens misturadas.
- Busca, filtros e páginas no catálogo; miniaturas desenhadas quando entram na tela.
- Exportação/importação de personagem em JSON e exportação de corpo inteiro em SVG editável.

## Arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `faces-core.js` | RNG, genoma, alelos, herança, crescimento e proporções corporais. Puro, sem DOM. |
| `character-catalog.js` | Amplia o catálogo com receitas que modificam a geometria. |
| `vector-character.js` | Paleta, rosto, cabelo e barba; uma cena para Canvas e SVG. |
| `vector-body.js` | Anatomia e contornos do corpo; membros, mãos e calças conectados. |
| `vector-wardrobe.js` | Receitas de vestuário, golas e retrato vestido. |
| `character-save.js` | Snapshot versionado e validação da importação. |
| `character-lab.js` | Controles, catálogos, família e navegação do laboratório. |
| `body-studies.html` | Folha de revisão visual usando o renderizador real. |
| `faces-render.js` | Estudo anterior, conservado como referência; não é usado pelo ateliê atual. |

## Identidade, apresentação e herança

O genoma guarda traços contínuos do rosto, pigmentação, pares de alelos de olhos
e cabelo, textura, altura e oito tendências corporais. Idade, roupa, expressão,
corte de cabelo e ajustes de constituição ficam em opções de apresentação.
Trocar roupa ou envelhecer não sorteia uma pessoa nova.

A geração de filhos seleciona alelos de cada pai e combina os traços contínuos
com variação determinística. As proporções de origem são combinadas entre os
pais; os seis perfis iniciais são amostragens artísticas, não categorias biológicas
exatas. A genética é uma simplificação para o jogo, não um modelo científico.

O corte de cabelo é uma preferência de estilo. A textura e a pigmentação são
herdáveis. A mesma seed, as mesmas opções de geração e a mesma versão do catálogo
reproduzem o mesmo genoma. Para preservar exatamente um personagem, salve o JSON.

Os IDs dos filhos na interface têm comprimento limitado; o histórico contém IDs
dos pais, sem armazenar árvores de genomas inteiras dentro de cada personagem.

## Uso do renderizador

Carregue os scripts na ordem usada em `index.html` e utilize:

```js
const mother = FaceCore.makeGenome('mae-42', { sex: 'F', ancestry: 'afro' })
const father = FaceCore.makeGenome('pai-81', { sex: 'M', ancestry: 'east' })
const child = FaceCore.childGenome(mother, father, 'filho-1')

VectorCharacter.render(canvas, child, { age: 25, outfit: 'jacket', view: 'body' })
const { svg } = VectorCharacter.build(child, { age: 25, outfit: 'jacket', view: 'body' })
const saved = CharacterSave.encode(child, { age: 25, outfit: 'jacket' })
const restored = CharacterSave.decode(saved)
```

O snapshot `paralelo-character`, versão 1, pertence a este laboratório e não
modifica o schema de save do jogo. A integração com os pacotes de produção e a
validação em aparelhos Android ainda não fazem parte deste protótipo.

## Verificação

Na raiz do repositório, sem instalar dependências:

```sh
node prototypes/faces/check-anatomy.cjs
node prototypes/faces/check-characters.cjs
```

Os checks verificam determinismo, ausência de mutação nas consultas, herança,
100 gerações, contagem e distinção geométrica dos estilos, casos de idade/peso/origem,
JSON/SVG restaurados e rejeição de snapshots inválidos. O segundo script também
mede uma amostra local de geração de genomas e SVGs; isso não mede FPS no celular.

Use a folha `body-studies.html` para inspecionar o desenho em diferentes pesos
e idades. Os testes de dados não substituem essa revisão visual.
