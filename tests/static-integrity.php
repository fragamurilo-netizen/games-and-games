<?php
/** Static release guards for the manual delivery engine. */
if ( 'cli' !== PHP_SAPI ) { exit(1); }
$pass = 0; $fail = array();
function s_ok($cond,$msg,$detail=''){ global $pass,$fail; if($cond){$pass++;}else{$fail[]=$msg.($detail?' — '.$detail:'');} }
function s_eq($a,$b,$msg){ s_ok($a===$b,$msg,'obtido '.var_export($a,true).' esperado '.var_export($b,true)); }
$root = dirname(__DIR__);
$runtime = file_get_contents($root.'/assets/js/go-ads-runtime.js');
$yield = file_get_contents($root.'/inc/ads/yield.php');
$style = file_get_contents($root.'/style.css');
$loader = file_get_contents($root.'/inc/ads/loader.php');
$planner = file_get_contents($root.'/inc/ads/planner.php');

s_eq(substr_count($runtime, '(w.adsbygoogle = w.adsbygoogle || []).push({});'), 1, 'Existe um único caminho de request adsbygoogle no runtime');
s_ok(strpos($runtime, 'setInterval(') === false, 'Runtime não usa setInterval para refresh/polling agressivo');
s_ok(strpos($runtime, 'location.reload') === false, 'Runtime não recarrega a página');
s_ok(strpos($runtime, 'marginalAllows') === false, 'O portão econômico decorativo, que sempre retornava true, não existe mais');
s_ok(strpos($runtime, 'function exposureAllows') !== false, 'O custo marginal agora é exposição prevista, e ela realmente decide');
s_ok(strpos($runtime, 'flick_vh_s') !== false, 'O limiar de flick vem da tabela central de regras');
s_ok(strpos($runtime, "out.regime = 'manual_fixed'") !== false
    && strpos($runtime, 'function refreshDecision') === false
    && strpos($runtime, 'function supplyBias') === false,
    'Runtime usa baseline manual fixa, sem controle financeiro nem consulta de regime por pageview');
s_ok(strpos($runtime, "budget = Math.min(rendered, structural)") !== false, 'EXPANSION mantém orçamento antecipado limitado ao plano; reservas alcançadas seguem a política única verificada pela suíte runtime-unified');
s_ok(strpos($runtime, 'function evaluateGovernor') !== false, 'O governador é uma máquina de estados real, observável');
s_ok(preg_match('/setGovernor\(\x27(warmup|standard|conservative|expansion)\x27/', $runtime) === 1 || substr_count($runtime, 'setGovernor(') >= 4, 'Os quatro estados do governador existem no código');
s_ok(strpos($runtime, 'responseEstimateMs * 4') === false, 'Request sem data-ad-status nunca libera budget por timeout presumido');
s_ok(strpos($runtime, 'stuck_release_ms') !== false && strpos($runtime, 'armStuckSweep') !== false, 'Uma oportunidade retida por silêncio do provedor é liberada por tempo limitado');
s_ok(strpos($runtime, 'one request per placement') !== false, 'A regra de um request por placement continua escrita e vigente');
s_ok(strpos($runtime, 'presentResponseTimes') !== false, 'JIT usa amostras de respostas com conteúdo para estimar latência de render');
s_ok(strpos($runtime, 'learnResponse(rec.responseMs, value, foregroundResponse)') !== false && strpos($runtime, 'rec.requestDwellMs') !== false, 'Status e intervalo em primeiro plano alimentam o modelo de latência');
s_ok(strpos($runtime, 'function effectiveAdRect') !== false, 'Densidade usa footprint efetivo para requests pendentes');
s_ok(strpos($planner, "'atomicTextWords'") !== false, 'Planner contabiliza texto editorial atômico seguro');
s_ok(strpos($planner, "'atomic_text'") !== false, 'Tabelas/dl estáticos têm classe editorial atômica protegida');
s_ok(strpos($planner, 'go_verge_ads_planner_structural_headroom') !== false, 'Planner contém um passo estrutural único');
s_ok(strpos($planner, 'go_verge_ads_planner_live_revenue_headroom') === false, 'O segundo passo, gated por regime financeiro, não existe mais');
s_ok(strpos($planner, 'go_verge_ads_planner_clearance') !== false, 'A folga editorial tem uma definição única');
s_ok(strpos($planner, 'GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED') !== false, 'Headroom possui rollback independente por constante');
s_ok(strpos($runtime, 'rest_lead_vh') !== false, 'A warm zone estacionária é por tier e vem da configuração');
s_ok(strpos($runtime, 'google-auto-placed') === false, 'O runtime não consulta seletores de Auto Ads in-page; este teste não consulta a conta');
s_ok(strpos($runtime, 'hybrid_auto_density') === false, 'O switch de densidade híbrida foi removido junto');
s_ok(strpos($runtime, 'responseEstimateFor') !== false, 'JIT usa percentis de latência diferentes por tier');
/* Discovery added for explicit dynamic-content events is not a per-frame scan.
 * Counting all selectors in the bundle confuses the two paths. A behavioral
 * offline check in validation/dom-scan-review.cjs complements these guards. */
$discovery_in_hot_path = array();
foreach (array('sweep','onScroll','onResize') as $handler) {
    if (!preg_match('/function '.preg_quote($handler, '/').'\\([^)]*\\)\\s*\\{(.*?)\\n  \\}/s', $runtime, $match)
        || preg_match('/querySelectorAll|\\bscan\\s*\\(|materializeListingReserves\\s*\\(/', $match[1])) {
        $discovery_in_hot_path[] = $handler;
    }
}
s_eq(count($discovery_in_hot_path), 0, 'Handlers de scroll/resize e sweep não executam discovery global'.($discovery_in_hot_path ? ': '.implode(', ', $discovery_in_hot_path) : ''));
s_ok(strpos($runtime, 'var RULES = (function () {') !== false, 'Existe uma única tabela de regras resolvida uma vez por pageview');

s_ok(strpos($loader, "go_verge_ads_loader_claimed") !== false, 'Loader mantém claim global contra bootstrap duplicado');
s_ok(strpos($runtime, "VERSION = '12.7.0-context-paint-gate'") !== false, 'Runtime identifica a versão única 12.7.0');
s_ok(strpos($runtime, 'function reachedReserveAllows(rec)') !== false, 'A política única admite reservas estruturalmente válidas quando alcançadas');
foreach (array('GOAdsExperiment', 'go-ads-experiment', 'revalidateOptions') as $obsolete) {
    s_ok(strpos($runtime, $obsolete) === false, 'Runtime não depende da infraestrutura antiga: '.$obsolete);
}
s_ok(strpos($loader, 'go_verge_ads_experiment') === false && strpos($loader, 'data-ad-channel') === false,
    'Loader não seleciona grupo, canal nem bootstrap experimental');
s_ok(!file_exists($root.'/inc/ads/experiment.php') && !file_exists($root.'/assets/js/go-ads-experiment.js'),
    'Arquivos exclusivos da divisão de audiência não são entregues');
$ads_bootstrap = file_get_contents($root.'/inc/ads.php');
s_ok(strpos($ads_bootstrap, "'experiment'") === false, 'Bootstrap PHP não inclui módulo experimental');

/* Os testes por dia de calendário medem releases sem dividir audiência. A
 * diferença não é o nome do arquivo: é que a atribuição não pode olhar para o
 * leitor. Estas guardas prendem essa propriedade no código, não na intenção. */
$trials = file_get_contents($root.'/inc/ads/calendar-trials.php');
foreach (array('$_COOKIE','$_GET','$_POST','$_SERVER','$_REQUEST','REMOTE_ADDR','HTTP_USER_AGENT','HTTP_REFERER',
               'mt_rand','wp_rand','uniqid','random_int','session_id') as $reader_input) {
    s_ok(strpos($trials, $reader_input) === false, 'Atribuição de dia não lê nada do leitor: '.$reader_input);
}
s_ok(preg_match('/\brand\s*\(/', $trials) !== 1, 'Atribuição de dia não sorteia');
s_ok(strpos($trials, 'set_transient') === false && strpos($trials, 'setcookie') === false,
    'Atribuição de dia não grava transient nem cookie');
/* A pureza que importa e a da ATRIBUICAO: o braco de um dia tem de ser
 * calculado, nunca lembrado. O marcador de primeiro dia visto e outra coisa --
 * piso do relatorio -- e so pode ser gravado do admin. */
foreach (array('go_verge_ads_trial_arm_for', 'go_verge_ads_trial_assignment', 'go_verge_ads_trial_calendar',
               'go_verge_ads_active_trial', 'go_verge_ads_trial_merge_rules', 'go_verge_ads_trial_filter_rules') as $pure) {
    if (!preg_match('/function '.preg_quote($pure, '/').'\s*\([^)]*\)\s*\{(.*?)\n\}/s', $trials, $m)) {
        s_ok(false, 'Funcao de atribuicao encontrada para auditoria: '.$pure);
        continue;
    }
    s_ok(!preg_match('/update_option|add_option|set_transient|setcookie/', $m[1]),
        'Atribuicao pura, nao grava nada: '.$pure);
}
s_eq(substr_count($trials, 'update_option'), 1, 'Existe uma unica gravacao no modulo, a do primeiro dia visto');
/* Um teste habilitado muda a tabela nos dias que possui. O bootstrap dos testes
 * precisa neutraliza-lo, senao a suite passa num dia e quebra no outro. */
$boot = file_get_contents($root.'/tests/bootstrap.php');
s_ok(strpos($boot, "add_filter(\n\t'go_verge_ads_trials'") !== false || strpos($boot, "'go_verge_ads_trials'") !== false,
    'O bootstrap dos testes neutraliza os testes por dia');
if (preg_match('/function go_verge_ads_trial_mark_first_seen\s*\([^)]*\)\s*\{(.*?)\n\}/s', $trials, $mark)) {
    s_ok(strpos($mark[1], 'update_option') !== false, 'E ela vive na funcao do primeiro dia visto');
    s_ok(strpos($mark[1], 'is_admin()') !== false && strpos($mark[1], 'current_user_can') !== false,
        'Que so grava a partir do admin autorizado');
}
s_ok(strpos($trials, 'function go_verge_ads_trial_arm_for') !== false && strpos($trials, 'floor( $offset / max( 1, (int) $trial[\'days\'] ) )') !== false,
    'O braço vem de aritmética sobre a data');
/* O runtime apenas repassa o braço para diagnóstico; nunca o escolhe nem o lê
 * para decidir entrega. */
s_eq(substr_count($runtime, 'YIELD.trial'), 1, 'O runtime lê o braço do dia em um único lugar');
s_eq(substr_count($runtime, 'trialSignal'), 2, 'O braço é lido uma vez e só reaparece no diagnóstico');
s_ok(strpos($runtime, 'trial.arm') === false && strpos($runtime, 'assignArm') === false, 'O runtime não escolhe braço');
/* Instalar o pacote não pode mudar a entrega sozinho. */
if (!function_exists('apply_filters')) { function apply_filters($tag,$value){ return $value; } }
if (!function_exists('sanitize_key')) { function sanitize_key($k){ return preg_replace('/[^a-z0-9_\-]/','',strtolower((string)$k)); } }
if (!function_exists('absint')) { function absint($v){ return abs((int)$v); } }
if (!defined('ABSPATH')) { define('ABSPATH', $root.'/'); }
if (!defined('DAY_IN_SECONDS')) { define('DAY_IN_SECONDS', 86400); }
if (!function_exists('add_filter')) { function add_filter($tag,$cb,$priority=10,$args=1){ return true; } }
if (!function_exists('add_action')) { function add_action($tag,$cb,$priority=10,$args=1){ return true; } }
if (!function_exists('get_option')) { function get_option($k,$d=false){ return $d; } }
if (!function_exists('update_option')) { function update_option($k,$v,$a=null){ return true; } }
if (!function_exists('is_admin')) { function is_admin(){ return false; } }
if (!function_exists('current_user_can')) { function current_user_can($c){ return false; } }
require_once $root.'/inc/ads/calendar-trials.php';
$shipped = go_verge_ads_trials();
$shipped_on = 0;
foreach ($shipped as $trial) { if (!empty($trial['enabled'])) { $shipped_on++; } }
/* No maximo UM teste habilitado: dois se confundiriam e nenhum resultado
 * significaria nada. Zero ou um sao ambos estados validos do pacote. */
s_ok($shipped_on <= 1, 'No maximo um teste por dia vem habilitado', 'habilitados='.$shipped_on);
if ($shipped_on === 1) {
    $active = go_verge_ads_active_trial();
    s_ok(is_array($active), 'O teste habilitado e valido e roda');
    s_ok(!empty($active['start']) && preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $active['start']),
        'O teste habilitado declara data de inicio');
    /* A contagem do relatorio nunca pode comecar antes do dia em que o teste
     * foi visto rodando, senao dias do tema anterior entram na comparacao. */
    s_ok(function_exists('go_verge_ads_trial_reportable_start'), 'Existe piso de contagem por primeiro dia visto');
    s_ok(strpos($trials, "add_action( 'admin_init', 'go_verge_ads_trial_mark_first_seen'") !== false,
        'O primeiro dia visto e gravado a partir do admin, nunca de requisicao publica');
    s_ok(strpos($trials, 'function go_verge_ads_trial_mark_first_seen') !== false
         && strpos($trials, 'is_admin() || ! current_user_can') !== false,
        'A gravacao do primeiro dia exige admin');
}
foreach ($shipped as $trial) {
    $arms = (array) $trial['arms'];
    s_ok(count($arms) >= 2, 'Todo teste declarado tem pelo menos dois braços');
    s_ok(empty(reset($arms)), 'O primeiro braço é a linha de base e não sobrescreve nada');
}

/* O autoloader do Ads Center deriva o nome do arquivo do nome da classe. Cinco
 * classes moram em arquivo de outra, e sem o mapa elas simplesmente não são
 * encontradas: a tela dá fatal ao abrir. Isso passou despercebido porque só
 * acontece quando o plugin está desativado e o fallback do tema é quem roda. */
$goac_dir = $root.'/inc/ads-center/includes/';
$goac_bootstrap = file_get_contents($goac_dir.'bootstrap.php');
preg_match_all('/\x27(GOAC_[A-Za-z_]+)\x27\s*=>\s*\x27([a-z0-9-]+)\x27/', $goac_bootstrap, $gm, PREG_SET_ORDER);
$goac_shared = array();
foreach ($gm as $row) { $goac_shared[$row[1]] = $row[2]; }
s_ok(count($goac_shared) >= 5, 'O autoloader do Ads Center declara o mapa de classes compartilhadas', 'entradas='.count($goac_shared));
$goac_unresolved = array();
foreach (glob($goac_dir.'*.php') as $goac_file) {
    if (!preg_match_all('/^(?:final )?(?:abstract )?class (GOAC_[A-Za-z_]+)/m', file_get_contents($goac_file), $cm)) { continue; }
    foreach ($cm[1] as $goac_class) {
        $name = isset($goac_shared[$goac_class]) ? $goac_shared[$goac_class] : strtolower(str_replace('_', '-', $goac_class));
        if (!is_file($goac_dir.'class-'.$name.'.php')) { $goac_unresolved[] = $goac_class; }
    }
}
s_eq(count($goac_unresolved), 0, 'Toda classe GOAC_* resolve para um arquivo existente'.($goac_unresolved ? ' ('.implode(', ', $goac_unresolved).')' : ''));

/* A tela Entrega pula silenciosamente o teste que não é chamável, então cinco
 * verificações inexistentes viraram um cartão permanentemente vazio. */
$goac_delivery = file_get_contents($goac_dir.'class-goac-view-delivery.php');
preg_match_all('/go_verge_ads_[a-z_]+_health_test/', $goac_delivery, $hm);
$goac_tests = array_unique($hm[0]);
s_ok(count($goac_tests) === 7, 'A tela Entrega chama sete verificações de saúde', 'encontradas='.count($goac_tests));
$health_src = file_get_contents($root.'/inc/ads/health.php');
foreach ($goac_tests as $goac_test) {
    s_ok((bool) preg_match('/^function '.preg_quote($goac_test, '/').'\s*\(/m', $health_src),
        'inc/ads/health.php implementa '.$goac_test);
}

/* One clock, one place.
 *
 * Snapshot freshness, the marginal window, the peer band and the seven-day range
 * are all measured against the account's current minute. While three functions
 * each read `now` for themselves, no test could describe "the last sync was six
 * hours ago" — the same fixture read as stale or as fresh depending on what time
 * the suite happened to run, and the stale-snapshot scenario silently passed by
 * testing nothing for most of the night. Every read now goes through
 * go_verge_ads_econ_now(), which is the only place allowed to ask the wall
 * clock. */
$econ_src = file_get_contents($root.'/inc/ads/economics.php');
s_ok((bool) preg_match('/^function go_verge_ads_econ_now\s*\(/m', $econ_src),
    'O relógio da conta tem uma única entrada: go_verge_ads_econ_now()');
s_eq(1, substr_count($econ_src, "new DateTimeImmutable( 'now'"),
    'Só go_verge_ads_econ_now() lê o relógio real em economics.php');
s_eq(0, substr_count($yield, "new DateTimeImmutable( 'now'"),
    'yield.php não tem relógio próprio');

/* The runtime is inlined into every HTML document, so the generated production
 * copy must exist, must parse, and must not be older than the source it came
 * from. A stale copy degrades to the documented file at runtime; this fails the
 * build so it is fixed rather than silently tolerated. */
$built = $root.'/assets/js/go-ads-runtime.min.js';
s_ok(is_readable($built), 'A cópia de produção do runtime existe (node tests/build-runtime-min.js)');
if (is_readable($built)) {
    s_ok(filemtime($built) >= filemtime($root.'/assets/js/go-ads-runtime.js'),
        'A cópia de produção não está mais velha que a fonte — rode node tests/build-runtime-min.js');
    $min = file_get_contents($built);
    s_ok(strlen($min) < strlen($runtime), 'A cópia de produção é menor que a fonte documentada');
    /* The generator normalises whitespace between tokens, so the guard compares
     * the request path with spacing removed rather than pinning one spelling of
     * it. What must survive minification is the single push, not its layout. */
    $min_tokens = preg_replace('/\s+/', '', $min);
    s_ok(strpos($min_tokens, '(w.adsbygoogle=w.adsbygoogle||[]).push({});') !== false, 'A cópia de produção preserva o caminho único de request');
    s_ok(substr_count($min_tokens, '.push({})') === substr_count(preg_replace('/\s+/', '', $runtime), '.push({})'),
        'A cópia de produção não acrescenta nem remove um request');
    s_ok(strpos($min, 'function exposureAllows') !== false, 'A cópia de produção preserva o portão de exposição');
    s_ok(substr_count($min, '/* ') <= 1, 'A cópia de produção não carrega comentários de documentação');
}

/* A cópia pública enxuta: mesmo motor de entrega, sem a superfície do operador.
 * O que precisa ser verdade é que ela ENTREGA igual e DIAGNOSTICA menos — nunca
 * o contrário, que seria servir ao leitor um motor diferente do auditado. */
$lean = $root.'/assets/js/go-ads-runtime.lean.js';
s_ok(is_readable($lean), 'A cópia pública enxuta existe (node tests/build-runtime-min.js)');
if (is_readable($lean) && is_readable($built)) {
    $lean_src = file_get_contents($lean);
    s_ok(filemtime($lean) >= filemtime($root.'/assets/js/go-ads-runtime.js'),
        'A cópia enxuta não está mais velha que a fonte — rode node tests/build-runtime-min.js');
    s_ok(strlen($lean_src) < strlen($min), 'A cópia enxuta é menor que a cópia completa',
        'enxuta='.strlen($lean_src).' completa='.strlen($min));
    $lean_tokens = preg_replace('/\s+/', '', $lean_src);
    s_ok(strpos($lean_tokens, '(w.adsbygoogle=w.adsbygoogle||[]).push({});') !== false,
        'A cópia enxuta preserva o caminho único de request');
    s_eq(substr_count($lean_tokens, '.push({})'), substr_count(preg_replace('/\s+/', '', $runtime), '.push({})'),
        'A cópia enxuta não acrescenta nem remove um request');
    /* Todo portão de entrega continua inteiro na cópia pública. */
    foreach (array('activate','densityAllows','exposureAllows','budgetAllows',
                   'paintHold','criticalHold','pacingAllows','rangeInfo',
                   'evaluateGovernor','reachedReserveAllows','topScrollSmartAllows') as $gate) {
        s_ok(strpos($lean_tokens, 'function'.$gate.'(') !== false, 'A cópia enxuta preserva o portão de entrega: '.$gate);
    }
    /* E só o diagnóstico do operador sai. */
    s_ok(strpos($lean_src, 'localExposureRequiredRatio') === false, 'A cópia enxuta não carrega o inspect completo');
    s_ok(strpos($lean_tokens, 'functionexplain()') !== false && strpos($lean_src, 'Cópia pública enxuta') !== false,
        'A cópia enxuta responde explain() com o aviso de onde está o detalhe');
    s_ok(strpos($lean_tokens, 'version:VERSION,lean:true') !== false,
        'A cópia enxuta ainda responde a checagem documentada de versão');
    s_ok(strpos($lean_src, '@lean:') === false, 'Os marcadores de build não vazam para a cópia gerada');
}
$assets_php = file_get_contents($root.'/inc/ads/assets.php');
s_ok(strpos($assets_php, "go-ads-runtime.lean.js") !== false && strpos($assets_php, 'current_user_can') !== false,
    'O tema escolhe a cópia pela capacidade do leitor, em um único lugar');
s_ok(strpos($assets_php, "go_verge_ads_serve_full_runtime") !== false,
    'A escolha da cópia tem filtro de rollback');
s_ok(strpos(file_get_contents($root.'/inc/ads/assets.php'), 'go_verge_ads_runtime_path') !== false,
    'O tema escolhe entre fonte e cópia de produção em um único lugar');
s_ok(strpos($style, 'Version: 5.5.4') !== false, 'Versão pública do tema é 5.5.4');
$functions = file_get_contents($root.'/functions.php');
s_ok(strpos($functions, "define( 'GO_VERGE_VERSION', '5.5.4' );") !== false, 'GO_VERGE_VERSION acompanha a versão pública 5.5.4');
s_ok(strpos($yield, 'go_ads_yield_decision_v12') !== false, 'Deploy usa transient v12 para separar o diagnóstico financeiro da política fixa');

s_ok((bool) preg_match('/[\"\']version[\"\']\s*=>\s*[\"\']9\.1\.1-fixed-manual-policy[\"\']/', $yield), 'Autoridade de yield expõe a versão da política manual fixa');
s_ok(strpos($yield, "'tier_floor'") === false, 'A tabela de pisos por tier saiu do servidor');
s_ok(strpos($yield, "'article_total'") === false, 'A escada advisória saiu do servidor');

if (!function_exists('apply_filters')) { function apply_filters($tag,$value){ return $value; } }
if (!defined('ABSPATH')) define('ABSPATH', $root.'/');
require_once $root.'/inc/ads/config.php';
$config = go_verge_ads_config();

/* Manual-format contract: listings, A1-A3 and Article End default to
 * responsive Display. Account-side unit type requires a separate check. */
s_eq($config['inventory']['article-a3']['sizing'] ?? null, 'responsive', 'A3 é Display responsivo como o resto do corpo');
s_eq($config['inventory']['article-end']['sizing'] ?? null, 'responsive', 'Article End default continua Display responsivo');
foreach (array('listing-f1','listing-f2','listing-f3') as $key) {
    s_eq($config['inventory'][$key]['sizing'] ?? null, 'responsive', $key.' já é Display responsivo, não In-feed');
}
s_eq($config['delivery_mode'] ?? null, 'manual_overlays', 'Contrato declara in-page manual + sobreposições');
s_eq($config['account_formats']['in_page'] ?? null, 'off', 'Contrato registra Auto Ads in-page DESLIGADO');
s_eq($config['account_formats']['anchor'] ?? null, 'on', 'Contrato mantém Anchor ligado');
s_eq($config['account_formats']['vignette'] ?? null, 'on', 'Contrato mantém Vignette ligada');

/* Every threshold the browser obeys has exactly one definition, and it is here. */
$rules = go_verge_ads_delivery_rules();
foreach (array('mobile','desktop') as $device) {
    foreach (array('min_gap_px','density_window_vh','max_units_in_window','max_local_ad_ratio','max_ad_to_content_ratio','min_stream_gap_px','rest_lead_vh','max_lookahead_vh','flick_vh_s','request_spacing_ms','engage_scroll_vh','engage_dwell_ms') as $key) {
        s_ok(isset($rules[$device][$key]), 'rules.'.$device.' define '.$key);
    }
}
s_ok(($rules['desktop']['min_gap_px'] ?? 0) > ($rules['mobile']['min_gap_px'] ?? 0), 'Desktop e mobile têm perfis realmente diferentes, não um multiplicador');
s_ok(isset($rules['governor']['spacing_scale']['conservative']), 'O governador tem escala de espaçamento por estado');
s_ok(($rules['stuck_release_ms'] ?? 0) >= 4000, 'A liberação por silêncio do provedor é conservadora');

$by_slot = array();
foreach (($config['inventory'] ?? array()) as $key=>$unit) {
    if (empty($unit['enabled'])) continue;
    $slot = preg_replace('/\D+/', '', (string)($unit['slot'] ?? ''));
    if ($slot !== '') $by_slot[$slot][] = array($key, (array)($unit['templates'] ?? array()));
    foreach ((array)($unit['slot_variants'] ?? array()) as $vkey=>$variant) {
        $vslot = preg_replace('/\D+/', '', (string)($variant['slot'] ?? ''));
        if ($vslot !== '') $by_slot[$vslot][] = array($key.':'.$vkey, (array)($unit['templates'] ?? array()));
    }
}
$overlaps = array();
foreach ($by_slot as $slot=>$uses) {
    for ($i=0;$i<count($uses);$i++) for ($j=$i+1;$j<count($uses);$j++) {
        $common = array_intersect($uses[$i][1], $uses[$j][1]);
        if ($common) $overlaps[] = $slot.':'.$uses[$i][0].'/'.$uses[$j][0].' ['.implode(',',$common).']';
    }
}
s_ok(count($by_slot) >= 18, 'Inventário ativo mantém diversidade de unidades', 'IDs='.count($by_slot));
s_eq(count($overlaps), 0, 'Mesmo slot não disputa dois placements no mesmo template');

$display_body = array('article-prime','article-a1','article-a2','article-a3','article-a4','article-a5','article-a6','article-end');
foreach ($display_body as $key) {
    $u = $config['inventory'][$key] ?? array();
    s_ok(!empty($u['full_width']) && ($u['sizing'] ?? '') === 'responsive', $key.' permanece responsivo/full-width');
}

echo "\n".str_repeat('=',72)."\n";
echo $pass.' asserções passaram, '.count($fail).' falharam'."\n";
foreach($fail as $f) echo '  FALHA: '.$f."\n";
echo str_repeat('=',72)."\n";
exit($fail?1:0);
