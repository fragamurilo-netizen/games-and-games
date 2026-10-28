# Alpha 1.0.1 — 26/10/2026

Atualização preparada a partir dos relatos de fechamento ao abrir o Mercado e iniciar
partidas, lentidão e textos que permaneciam em português com inglês selecionado.
Não havia modelo de celular, versão do Android nem logcat dos aparelhos afetados.

## Alterações

- Mercado: busca e sugestões executadas pelo worker exclusivo do GameManager, com
  a interface protegida pelo fluxo de trabalho ocupado já usado no jogo. A avaliação
  deixou de usar várias threads que compartilhavam o cache de referência por frame.
- A referência de avaliação é capturada uma vez por posição; o cálculo da projeção
  pode reutilizar a nota já obtida, preservando a fórmula das estrelas.
- Tabelas: montagem progressiva com orçamento de 3 ms por frame. No Android e no
  layout compacto, a primeira página tem 20 linhas; Mostrar mais carrega outras 20.
  Isso reduz a alocação inicial de retratos e células, sem reduzir a base pesquisável.
- Partidas: preparação do calendário e carregamento da cena em segundo plano. A
  transição só ocorre quando existe a partida do usuário; pedidos duplicados são rejeitados.
- O recurso da tela de Mercado é carregado durante geração/carregamento da carreira.
- O gerador solta a referência e o callback após entregar o mundo. Isso evita manter
  um mundo antigo vivo depois de abrir outra carreira.
- Inglês: 1.129 textos adicionados, incluindo Mercado, contratos, elenco, base,
  seleção, estatísticas, instruções e palestras. As células de tabela agora traduzem
  explicitamente o conteúdo antes de desativar a tradução automática do Control.
- Tradução de trechos compostos, variantes em minúsculas e espaços nas bordas;
  cache protegido por Mutex e valores sem letras dispensados da busca por moldes.
- Versão 1.0.1, versionCode 23. Preset Android Alpha mantém `sem_trava`.

## Validação

- Compilação de scripts sem erros.
- `tests/mobile_regression.gd`: passou.
- Cinco testes do núcleo: partida ao vivo/instantânea, troca de formação, save/load,
  negociações do usuário e simulação paralela/sequencial: 5 passaram, zero falhas.
- `tests/android_reliability.gd`: busca em pt/en/es, filtros/abas, tradução de células,
  carregamento progressivo, Mercado após save/load, preparação assíncrona, rejeição de
  chamada duplicada, início, fim e processamento de uma partida.
- Inspeção real com OpenGL em 390×844, 844×390, 800×1280 e 1280×800; Mercado e partida.
  Capturas e logs locais em `publicacao-local/hotfix-*` (ignorados pelo Git).
- Medição no PC: abertura da busca depois do carregamento antecipado em 2–8 ms,
  com o trabalho pesado em segundo plano. Montagem da tela da partida em 56–303 ms,
  comparada a 1.357 ms na reprodução inicial. Não são medições de um celular.
- Alguns encerramentos dos testes com vídeo exibem avisos de RIDs/objetos ainda vivos
  na saída do processo; não houve erro de script nos fluxos validados nem reprodução
  dos fechamentos relatados. Não há comprovação de execução em Android físico.
- `release_check.py`: o único erro é a ausência das oito capturas de loja no checkout,
  já ausentes antes deste trabalho. Os arquivos removidos não integram este commit.
  Atualizar o AAB no Alpha pode manter as imagens já cadastradas na Play.

## Arquivo para a Google Play

- Caminho: `mais-uma-rodada/build/MaisUmaRodada-1.0.1-alpha.aab`.
- Tamanho: 49.586.823 bytes.
- SHA-256: `1e27fd527d537baee61b2510c211f03f1fb8746b24116048604222067a9877f7`.
- Pacote `mais.uma.rodada`, versão `1.0.1 (23)`, mínimo SDK 24, alvo SDK 36, ARM64.
- Bundletool validou o bundle; assinatura JAR verificada e certificado de upload
  igual ao do Alpha 22. Bibliotecas ELF com alinhamento LOAD de 16 KB.
- `sem_trava` presente no project.binary do asset pack instalado junto com o app.
  Scripts de testes, ferramentas e reprodução local excluídos do pacote.
- Chave e senha permanecem fora do Git, sem troca da chave de upload.

## Envio pendente

O AAB **não foi enviado à Google Play** nesta atualização. O controle do Chrome foi
interrompido porque não conseguiu determinar a URL atual com segurança; não foram
feitas outras ações na interface depois desse bloqueio.

Próximo passo no Play Console: app Mais Uma Rodada: Manager → Teste fechado → Alpha →
criar versão → enviar o AAB 23 → incluir as notas 1.0.1 → revisar e enviar as mudanças.
Preservar o grupo de testadores e os países já configurados. A distribuição aos
testadores só deve ser anunciada depois da confirmação de publicação pelo Console.

Referências usadas na investigação: [ANRs no Android](https://developer.android.com/topic/performance/vitals/anr)
e [segurança de threads do Godot](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).
