# Consertar a entrega de AVIF no servidor

O painel (**Ferramentas → Saúde do site**) manda ler este arquivo. Ele descreve
uma correção de **servidor**, não de tema: nenhuma atualização do Overdrive
resolve isso, porque o problema acontece antes do PHP entrar em cena.

---

## 1. Confirmar que é isso mesmo, em 10 segundos

Pegue a URL de qualquer imagem `.avif` do site (clique com o botão direito numa
capa → "Abrir imagem em nova aba" e copie o endereço). Depois, no terminal:

```sh
curl -sI "https://gameoverdrive.com.br/wp-content/uploads/2026/08/exemplo.avif" | grep -i "content-type\|x-content-type"
```

**Quebrado** é assim:

```
content-type: text/plain
x-content-type-options: nosniff
```

**Certo** é assim:

```
content-type: image/avif
```

Sem terminal: abra a URL da imagem numa aba, tecle F12 → aba **Network** →
recarregue → clique no arquivo → **Headers** → procure `Content-Type`.

> O navegador pinta a imagem nos dois casos, porque ele cheira os bytes e
> ignora o cabeçalho. Por isso o erro é invisível na redação. O pipeline de
> imagens do Google **não** ignora: ele lê o cabeçalho, vê `text/plain`,
> conclui que aquilo não é imagem e descarta. A matéria entra no Discover sem
> imagem grande — e o Discover não distribui história sem imagem grande.

---

## 2. A correção

Uma linha no `.htaccess` da **raiz** do site (a pasta que contém `wp-config.php`,
`wp-admin/` e `wp-content/`):

```apache
AddType image/avif .avif
AddType image/avif-sequence .avifs
```

### Onde exatamente

O WordPress reescreve tudo que estiver **entre** `# BEGIN WordPress` e
`# END WordPress`. Qualquer coisa colocada ali dentro some sozinha na próxima
vez que o WordPress mexer nas permalinks. Coloque **antes** do bloco:

```apache
# Overdrive — tipo MIME correto para AVIF.
# Sem isto o servidor responde .avif como text/plain e o pipeline de imagens
# do Google recusa a imagem. Deve ficar FORA do bloco # BEGIN WordPress.
AddType image/avif .avif
AddType image/avif-sequence .avifs

# BEGIN WordPress
# ... não mexa aqui dentro ...
# END WordPress
```

### Como chegar no arquivo

Escolha o caminho que você tem:

**a) Painel da hospedagem (mais comum).** cPanel / hPanel / Plesk →
**Gerenciador de Arquivos** → pasta `public_html` (ou `www`, ou o domínio) →
ative **"Mostrar arquivos ocultos"**, senão o `.htaccess` não aparece → clique
com o botão direito → **Editar**.

**b) FTP/SFTP.** FileZilla → Servidor → "Forçar exibição de arquivos ocultos" →
baixe o `.htaccess` da raiz, edite, suba de volta.

**c) SSH.**

```sh
cd /caminho/do/site
cp .htaccess .htaccess.backup-$(date +%F)
sed -i '1i AddType image/avif .avif\nAddType image/avif-sequence .avifs\n' .htaccess
```

**Antes de editar, faça uma cópia.** Um `.htaccess` com erro de sintaxe derruba
o site inteiro com erro 500. Se isso acontecer, restaure a cópia e o site volta
na hora.

---

## 3. Conferir que funcionou

Rode o mesmo `curl` do passo 1. Agora tem que dizer `image/avif`.

Se ainda disser `text/plain`, limpe o cache do CDN — a resposta antiga pode
estar guardada na borda. Depois teste de novo com um parâmetro para furar o
cache:

```sh
curl -sI "https://gameoverdrive.com.br/wp-content/uploads/2026/08/exemplo.avif?v=$(date +%s)" | grep -i content-type
```

Depois, em **Ferramentas → Saúde do site**, a verificação **"Entrega de imagens
AVIF"** deve confirmar `image/avif`.

### E aí falta um passo que é fácil de não ver

Confirmar o servidor **não** é o fim. O tema trata AVIF como formato que este
servidor não entrega — e essa decisão foi tomada quando ele realmente não
entregava. Enquanto ela valer, matéria com capa AVIF continua saindo sem
`og:image` e sem imagem representativa, **mesmo com o servidor já correto**.

A verificação avisa quando os dois discordam ("O servidor já entrega AVIF, mas o
tema ainda está recusando"). Para liberar, uma linha em `wp-config.php`, antes de
`/* That's all, stop editing! */`:

```php
add_filter( 'go_verge_allow_avif_uploads', '__return_true' );
```

Isso reabre junto: upload de AVIF, AVIF como `og:image`, AVIF como imagem de
schema, e a leitura de prontidão do Discover. É de propósito que seja um
interruptor só — as quatro decisões dependem da mesma pergunta, e tê-las
separadas foi como o site ficou com três respostas diferentes para ela.

Confirme as duas verificações em verde antes de considerar resolvido.

---

## 4. Se não funcionar

**O servidor é nginx.** `.htaccess` não existe em nginx — o arquivo é lido e
ignorado. Peça ao suporte da hospedagem, com estas palavras:

> "Preciso que o servidor responda arquivos `.avif` com
> `Content-Type: image/avif`. Hoje responde `text/plain`, o que quebra a
> indexação de imagens. Em nginx, é adicionar `image/avif avif;` ao
> `mime.types`."

**É LiteSpeed ou Apache e mesmo assim não mudou.** Algumas hospedagens ignoram
`AddType` quando têm um mapa MIME próprio, ou bloqueiam `AddType` via
`AllowOverride`. Mesma mensagem acima para o suporte, trocando "nginx" por
"Apache/LiteSpeed".

**Você não tem acesso ao servidor e ninguém vai mexer nisso.** Então pule a
correção e vá para o passo 5 — ele resolve o efeito sem depender de ninguém.

---

## 5. O acervo já publicado, que a correção do MIME **não** conserta sozinha

Mesmo com o MIME corrigido, um AVIF continua sem sub-tamanhos gerados: o editor
de imagem desta hospedagem não redimensiona AVIF, então `-1600x900.avif` e
companhia respondem 404. Sem sub-tamanho, o recorte `go_discover_16x9` não
existe e a cadeia cai para o arquivo original.

Ou seja: são **dois** problemas independentes no mesmo formato. Corrigir o MIME
resolve o primeiro. O segundo só sai de duas formas:

**Caminho rápido, sem depender de ninguém:** reenviar a capa em **JPEG ou PNG**
nas matérias afetadas. O site converte os recortes para WebP sozinho, e aí a
matéria passa a ter recorte 16:9, `og:image` e imagem de schema — os três que
faltavam.

**Quais matérias?** Não precisa adivinhar. **Ferramentas → Saúde do site** →
**"Imagens do acervo elegíveis ao Discover"** lista quantas estão quebradas e dá
os links clicáveis das primeiras.

Comece pelas mais recentes e pelas que já renderam bem — o Discover olha pouco
para trás, e matéria de dois meses atrás não vai voltar a circular.

> Upload de AVIF já está bloqueado no tema desde 18/08/2026, então matéria nova
> não entra mais nesse estado. Este passo é só para o que foi publicado antes.

---

## 6. Depois de tudo isso

Se o MIME estiver `image/avif`, as capas recentes estiverem em JPEG/PNG e o
Discover continuar em zero por mais uma ou duas semanas, **a causa não é
técnica**. Antes de mexer em mais código, abra o Search Console e verifique:

- **Segurança e ações manuais → Ações manuais**
- **Segurança e ações manuais → Problemas de segurança**

Uma queda total e abrupta — de dezenas de milhares de cliques por dia para zero
em poucos dias — é mais típica de ação de política do que de degradação técnica
gradual. Nenhum código conserta isso, e continuar otimizando entrega enquanto
for esse o caso é tempo jogado fora.
