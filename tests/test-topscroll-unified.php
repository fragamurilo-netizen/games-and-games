<?php
/** Read-only initial preset; explicit deployment overrides retain authority. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
$GLOBALS['go_topscroll_options'] = array();
$GLOBALS['go_topscroll_writes'] = array();
function get_option( $name, $default = false ) {
    return array_key_exists( $name, $GLOBALS['go_topscroll_options'] ) ? $GLOBALS['go_topscroll_options'][$name] : $default;
}
function update_option( $name, $value, $autoload = null ) {
    $GLOBALS['go_topscroll_writes'][] = array( $name, $value, $autoload );
    $GLOBALS['go_topscroll_options'][$name] = $value;
    return true;
}
$custom_default = in_array('--custom-default', (array)$argv, true);
if ($custom_default) { define('GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT', 3); }
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/topscroll.php';
require_once GO_VERGE_DIR . '/inc/ads/topscroll-admin.php';
function esc_html_e($value, $domain='') { echo esc_html($value); }
function settings_fields($group) {}
function submit_button() {}
function checked($value, $current=true, $echo=true) {
    $out=$value==$current?'checked="checked"':'';
    if($echo) { echo $out; }
    return $out;
}
function topscroll_admin_html() {
    $GLOBALS['go_test_is_admin_user']=true;
    ob_start(); go_verge_adsense_render_topscroll_admin_page(); $html=ob_get_clean();
    $GLOBALS['go_test_is_admin_user']=false;
    return $html;
}
function topscroll_reset( $value = null, $applied = false ) {
    $GLOBALS['go_topscroll_options'] = array();
    $GLOBALS['go_topscroll_writes'] = array();
    $GLOBALS['go_test_filters']['go_verge_adsense_topscroll_config'] = array();
    $GLOBALS['go_test_filters']['go_verge_adsense_topscroll_enabled'] = array();
    if (null !== $value) { $GLOBALS['go_topscroll_options'][GO_VERGE_ADSENSE_TOPSCROLL_OPTION]=$value; }
    if ($applied) { $GLOBALS['go_topscroll_options'][GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION]=1; }
}
function topscroll_saved() { return get_option(GO_VERGE_ADSENSE_TOPSCROLL_OPTION, array()); }
if ($custom_default) {
    topscroll_reset(array('enabled'=>false,'frequency_max'=>4));
    $c=go_verge_adsense_topscroll_config();
    go_test_equals(3,$c['frequency_max'],'Default customizado continua override explícito no baseline');
    go_test_equals('default-constant',$c['frequency_source'],'Origem do default customizado é explícita');
    go_test_equals(true,$c['enabled'],'Baseline reinicia opção de habilitação');
    go_test_equals(3,$c['external_overrides']['GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT'],'Override customizado consta do relatório');
    go_test_equals(4,topscroll_saved()['frequency_max'],'Resolver não persiste o reset em página pública');
    go_test_equals(0,count($GLOBALS['go_topscroll_writes']),'Nenhuma escrita na resolução do baseline customizado');
    topscroll_reset(array('enabled'=>true,'frequency_max'=>4),true);
    go_test_equals(4,go_verge_adsense_topscroll_config()['frequency_max'],'Escolha salva após baseline continua prevalecendo sobre DEFAULT');
    exit;
}

topscroll_reset();
$c=go_verge_adsense_topscroll_config();
go_test_equals(6,$c['frequency_max'],'Sem opção: baseline começa em seis');
go_test_equals('baseline',$c['frequency_source'],'Baseline ainda não persistido é identificado');
go_test_equals(true,$c['baseline_pending'],'Migração administrativa está pendente');
go_test_equals(true,$c['enabled'],'Unidade habilitada com IDs presentes');
go_test_equals(86400000,$c['frequency_window_ms'],'Janela móvel continua em 24h');
go_test_equals(4,$c['smart_free_fills'],'Primeiros quatro não exigem engajamento adicional');
go_test_equals(3,$c['smart_fifth_pages'],'Quinta exige três páginas como alternativa');
go_test_equals(60000,$c['smart_fifth_active_ms'],'Quinta exige 60s ativos como alternativa');
go_test_equals(4,$c['smart_sixth_pages'],'Sexta exige quatro páginas como alternativa');
go_test_equals(120000,$c['smart_sixth_active_ms'],'Sexta exige 120s ativos como alternativa');
go_test_equals(0,count($GLOBALS['go_topscroll_writes']),'Getter não cria sequer marcador');
$html=topscroll_admin_html();
go_test_ok(1===preg_match('/<input id="go-topscroll-frequency"[^>]*>/', $html, $field) && false===strpos($field[0],'readonly'),'Sem constante, operador pode editar frequência');
foreach(array(0,1,2,3,4,5,6) as $legacy) {
    foreach(array(true,false) as $enabled) {
        $before=array('enabled'=>$enabled,'frequency_max'=>$legacy,'publisher_note'=>'preserve');
        topscroll_reset($before);
        $GLOBALS['go_topscroll_options'][GO_VERGE_ADSENSE_TOPSCROLL_READY_MIGRATION_OPTION]=1;
        $c=go_verge_adsense_topscroll_config();
        go_test_equals(6,$c['frequency_max'],'Reset inicial ignora frequência antiga'.$legacy.' enabled'.(int)$enabled);
        go_test_equals(true,$c['enabled'],'Reset inicial habilita a opção antiga'.$legacy.' enabled'.(int)$enabled);
        go_test_equals($before,topscroll_saved(),'Getter preserva valor bruto antigo'.$legacy.' enabled'.(int)$enabled);
        go_test_equals(0,count($GLOBALS['go_topscroll_writes']),'Sem writes no frontend'.$legacy.' enabled'.(int)$enabled);
        go_test_equals('preserve',go_verge_adsense_topscroll_baseline_values($before)['publisher_note'],'Campos extras sobrevivem ao baseline'.$legacy.' enabled'.(int)$enabled);
        $GLOBALS['go_topscroll_options'][GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION]=1;
        $again=go_verge_adsense_topscroll_config();
        go_test_equals($legacy,$again['frequency_max'],'Após marcador, escolha explícita de frequência permanece'.$legacy);
        go_test_equals($enabled,$again['enabled'],'Após marcador, escolha explícita de habilitação permanece'.$legacy.' enabled'.(int)$enabled);
    }
}

topscroll_reset(array('enabled'=>false,'frequency_max'=>3));
add_filter('go_verge_adsense_topscroll_config', static function($c){ $c['frequency_max']=2; return $c; });
$c=go_verge_adsense_topscroll_config();
go_test_equals(2,$c['frequency_max'],'Filtro explícito de cap permanece efetivo');
go_test_equals('filter',$c['frequency_source'],'Origem alterada por filtro é identificada');
go_test_equals('registered',$c['external_overrides']['go_verge_adsense_topscroll_config'],'Filtro registrado é reportado');
go_test_equals(3,topscroll_saved()['frequency_max'],'Filtro não permite escrita pública escondida');

topscroll_reset(array('enabled'=>true,'frequency_max'=>3));
add_filter('go_verge_adsense_topscroll_config', static function($c){ $c['frequency_max']=6; return $c; }, 0);
$c=go_verge_adsense_topscroll_config();
go_test_equals('registered',$c['external_overrides']['go_verge_adsense_topscroll_config'],'Mesmo valor final e prioridade0 não ocultam existência de filtro');

topscroll_reset(array('enabled'=>true,'frequency_max'=>4));
add_filter('go_verge_adsense_topscroll_enabled', static function($enabled){ return false; });
$c=go_verge_adsense_topscroll_config();
go_test_equals(false,$c['enabled'],'Filtro de emergência continua autoritativo');
go_test_equals('registered',$c['external_overrides']['go_verge_adsense_topscroll_enabled'],'Filtro de habilitação é reportado');

/* Constants are process-wide; priority follows the historical public API. */
define('GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX',3);
topscroll_reset(array('enabled'=>true,'frequency_max'=>4));
$c=go_verge_adsense_topscroll_config();
go_test_equals(3,$c['frequency_max'],'MAX legado prevalece sobre baseline');
go_test_equals('legacy-constant',$c['frequency_source'],'Fonte legacy-constant explícita');
go_test_equals(3,$c['external_overrides']['GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX'],'Valor MAX é reportado');
$html=topscroll_admin_html();
go_test_ok(1===preg_match('/<input id="go-topscroll-frequency"[^>]*>/', $html, $field) && false!==strpos($field[0],'readonly'),'MAX legado torna campo somente leitura');
go_test_ok(false!==strpos($html,'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX'),'UI identifica constante MAX');
define('GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT',4);
topscroll_reset(array('enabled'=>false,'frequency_max'=>3));
$c=go_verge_adsense_topscroll_config();
go_test_equals(4,$c['frequency_max'],'LIMIT atual prevalece sobre MAX legado');
go_test_equals('constant',$c['frequency_source'],'Fonte constant explícita');
$html=topscroll_admin_html();
go_test_ok(1===preg_match('/<input id="go-topscroll-frequency"[^>]*>/', $html, $field) && false!==strpos($field[0],'readonly'),'LIMIT torna campo somente leitura');
go_test_ok(false!==strpos($html,'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT'),'UI identifica constante LIMIT');
define('GO_VERGE_ADSENSE_TOPSCROLL_ENABLED',false);
topscroll_reset(array('enabled'=>true,'frequency_max'=>3));
$c=go_verge_adsense_topscroll_config();
go_test_equals(false,$c['enabled'],'Constante de emergência não é desfeita pelo reset');
go_test_equals(false,$c['external_overrides']['GO_VERGE_ADSENSE_TOPSCROLL_ENABLED'],'Emergência é registrada no diagnóstico');
go_test_equals('constant',$c['source'],'Fonte de habilitação explícita');
go_test_equals(0,count($GLOBALS['go_topscroll_writes']),'Constantes também não geram writes públicos');
