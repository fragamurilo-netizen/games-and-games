<?php
/** 5,000 deterministic economic scenarios for the server regime controller. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/economics.php';
require_once GO_VERGE_DIR . '/inc/ads/yield.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

mt_srand( 4600 );
$fail = array(); $checks = 0; $regimes = array();
$units = go_test_unit_rows(array(
  '7792311754'=>array('request_rpm'=>.62,'requests'=>40000,'coverage'=>.90),
  '3572313419'=>array('request_rpm'=>.55,'requests'=>38000,'coverage'=>.90),
  '5017324239'=>array('request_rpm'=>.49,'requests'=>30000,'coverage'=>.88),
  '5223365459'=>array('request_rpm'=>.44,'requests'=>26000,'coverage'=>.88),
  '6368539121'=>array('request_rpm'=>.40,'requests'=>22000,'coverage'=>.87),
  '7554015324'=>array('request_rpm'=>.34,'requests'=>18000,'coverage'=>.86),
  '6240933652'=>array('request_rpm'=>.27,'requests'=>14000,'coverage'=>.86),
  '6568236715'=>array('request_rpm'=>.23,'requests'=>11000,'coverage'=>.85),
  '8238832024'=>array('request_rpm'=>.17,'requests'=>8000,'coverage'=>.84),
  '5255155049'=>array('request_rpm'=>.14,'requests'=>6000,'coverage'=>.84),
  '5798080525'=>array('request_rpm'=>.31,'requests'=>9000,'coverage'=>.87),
));

for($i=0;$i<3000;$i++){
  $imp = 4.3 + mt_rand(0,420)/100;       // 4.3..8.5 imp/PV
  $irpm = .15 + mt_rand(0,80)/100;       // .15..95
  $coverage = .45 + mt_rand(0,52)/100;   // .45..97
  $pvph = 500 + mt_rand(0,2500);
  $requests = 20000 + mt_rand(0,160000);
  go_test_flush_transients();
  $GLOBALS['go_test_goac']=array(
    'connected'=>true,'today'=>'2026-09-20','unit_rows'=>$units,
    'intraday'=>array_merge(go_test_history(8,1200,7.8,.59),array('2026-09-20'=>go_test_day($pvph,$imp,$irpm))),
    'daily_rows'=>array('2026-09-20'=>array('ad_requests'=>$requests,'matched_requests'=>$requests*$coverage)),
  );
  $d=go_verge_ads_yield_decision(true); $regimes[$d['regime']]=($regimes[$d['regime']]??0)+1;
  $checks++; if($d['supply_bias']<0||$d['supply_bias']>2)$fail[]="#$i bias";
  $checks++; if($coverage<.68 && $irpm>.20 && $d['regime']!=='coverage_stress')$fail[]="#$i low coverage {$coverage} regime {$d['regime']}";
  $checks++; if($d['regime']==='coverage_stress' && (int)$d['supply_bias']!==0)$fail[]="#$i coverage bias {$d['supply_bias']}";
  /* Severity is measured against the reference the decision itself reports, not
   * against a number copied from the frontier. The reference moved once (7.80 was
   * the Auto Ads in-page era) and this line silently stopped testing severity. */
  $severe = ((float)$d['delivery_reference_pv'] - $imp) >= 1.20;
  $checks++; if($coverage>=.82 && $irpm>.20 && $severe && (int)$d['supply_bias']!==2)$fail[]="#$i healthy severe gap bias {$d['supply_bias']} ref {$d['delivery_reference_pv']} imp {$imp}";
  $checks++; if(($d['revenue_pressure']??-1)<0||($d['revenue_pressure']??2)>1)$fail[]="#$i pressure {$d['revenue_pressure']}";
}

/* The public signal the browser receives is bounded and money-free. */
go_test_flush_transients();
$GLOBALS['go_test_goac']=array(
  'connected'=>true,'today'=>'2026-09-20','unit_rows'=>$units,
  'intraday'=>array_merge(go_test_history(8,1200,7.8,.59),array('2026-09-20'=>go_test_day(1200,5.6,.43))),
  'daily_rows'=>array('2026-09-20'=>array('ad_requests'=>140000,'matched_requests'=>128800)),
);
go_verge_ads_yield_decision(true);
$signal=go_verge_ads_yield_public_signal();
$checks++; if(isset($signal['floor']))$fail[]='public signal still exposes a marginal floor';
$checks++; if(isset($signal['tier_floor']))$fail[]='public signal still exposes tier floors';
$checks++; if(isset($signal['slot_risk']))$fail[]='public signal still exposes an unused risk list';
foreach(array('regime','supply_bias','pacing_scale','tier_lookahead','slot_value','slot_coverage','slot_viewability') as $key){
  $checks++; if(!array_key_exists($key,$signal))$fail[]="public signal missing {$key}";
}
$checks++; if($signal['supply_bias']<0||$signal['supply_bias']>2)$fail[]='supply_bias out of bounds';
$checks++; if($signal['pacing_scale']<.55||$signal['pacing_scale']>1.6)$fail[]='pacing_scale out of bounds';
foreach((array)$signal['tier_lookahead'] as $tier=>$value){
  $checks++; if($value<1.0||$value>1.25)$fail[]="tier_lookahead {$tier}={$value} out of bounds";
}
$forbidden=array('earnings','page_rpm','impression_rpm','page_views','clicks','price','revenue_pressure','floor_scale','required_impressions_pv','delivery_reference_pv','delivered_impressions_pv','day_coverage');
$walk=function($node) use (&$walk,$forbidden,&$fail,&$checks){
  if(!is_array($node))return;
  foreach($node as $key=>$value){
    $checks++;
    if(is_string($key)&&in_array($key,$forbidden,true))$fail[]="public signal leaks financial field {$key}";
    $walk($value);
  }
};
$walk($signal);

/* The rule table the browser obeys is complete, bounded and device-split. */
$rules=go_verge_ads_delivery_rules();
foreach(array('mobile','desktop') as $device){
  foreach(array('min_gap_px','density_window_vh','max_units_in_window','max_local_ad_ratio','max_ad_to_content_ratio','min_stream_gap_px','rest_lead_vh','rest_lead_min_px','rest_lead_max_px','max_lookahead_vh','flick_vh_s','request_spacing_ms','engage_scroll_vh','engage_dwell_ms') as $key){
    $checks++; if(!array_key_exists($key,$rules[$device]))$fail[]="rules.{$device} missing {$key}";
  }
  foreach(array('reach','premium','standard','deep','completion') as $tier){
    $checks++; if(!isset($rules[$device]['rest_lead_vh'][$tier]))$fail[]="rules.{$device}.rest_lead_vh missing {$tier}";
  }
  $checks++; if($rules[$device]['min_gap_px']<go_verge_ads_planner_clearance()['height'])$fail[]="rules.{$device}.min_gap_px below planner clearance";
}
$checks++; if($rules['desktop']['min_gap_px']<=$rules['mobile']['min_gap_px'])$fail[]='desktop must space wider than mobile';
$checks++; if($rules['mobile']['flick_vh_s']>=$rules['desktop']['flick_vh_s'])$fail[]='touch flick threshold must be lower than wheel';
$checks++; if($rules['stuck_release_ms']<4000)$fail[]='stuck release too aggressive';

echo json_encode(array('cases'=>3000,'checks'=>$checks,'regimes'=>$regimes,'failureCount'=>count($fail),'failures'=>array_slice($fail,0,20)),JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";
exit($fail?1:0);
