<?php
/** Isolated, bounded Search refresh for the article list. */
if (!defined('ABSPATH')) { exit; }
add_action('wp_ajax_go_fast_search',static function(){
 if(!current_user_can('edit_posts')){wp_send_json_error(array('message'=>'Sem permissão.'),403);}
 check_ajax_referer('go_fast_search','nonce');
 $ids=isset($_POST['post_ids'])&&is_array($_POST['post_ids'])?array_slice(array_unique(array_filter(array_map('absint',$_POST['post_ids']))),0,20):array();
 $ids=array_values(array_filter($ids,static function($id){return current_user_can('edit_post',$id)&&'publish'===get_post_status($id);}));
 if(!$ids){wp_send_json_success(array('rows'=>array()));}
 if(!class_exists('GED_Search_Console')||!method_exists('GED_Search_Console','visible_page_snapshot')){wp_send_json_error(array('message'=>'Atualização rápida requer Lume 6.21.2.'),503);}
 $result=(new GED_Search_Console())->visible_page_snapshot($ids);
 if(is_wp_error($result)){wp_send_json_error(array('message'=>$result->get_error_message()),503);}
 $fallback=go_verge_admin_gsc_metrics(array_keys($result['rows']));
 foreach($result['rows'] as $id=>&$row){$row['fallback_position']=(float)($fallback[$id]['search_position']??0);$row['fallback_impressions']=(int)($fallback[$id]['search_impressions']??0);}unset($row);
 wp_send_json_success($result);
});
add_action('admin_enqueue_scripts',static function($hook){
 $screen=get_current_screen();if('edit.php'!==$hook||!$screen||'post'!==$screen->post_type||!current_user_can('edit_posts'))return;
 if(!class_exists('GED_Search_Console')||!GED_Search_Console::connected())return;
 $rel='/assets/js/admin-fast-search.js';wp_enqueue_script('go-fast-search',GO_VERGE_URI.$rel,array(),go_verge_asset_version($rel),true);
 wp_add_inline_script('go-fast-search','window.GOFastSearch='.wp_json_encode(array('url'=>admin_url('admin-ajax.php'),'nonce'=>wp_create_nonce('go_fast_search'))).';','before');
});
