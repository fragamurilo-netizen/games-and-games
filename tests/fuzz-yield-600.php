<?php
if ('cli' !== PHP_SAPI) exit;
require_once __DIR__.'/bootstrap.php';
require_once GO_VERGE_DIR.'/inc/ads/config.php';
require_once GO_VERGE_DIR.'/inc/ads/economics.php';
require_once GO_VERGE_DIR.'/inc/ads/yield.php';

function fy_decide($scenario){ go_test_flush_transients(); $GLOBALS['go_test_goac']=array_merge(['connected'=>true,'today'=>'2026-09-20','intraday'=>[],'unit_rows'=>[]],$scenario); return go_verge_ads_yield_public_signal(); }
function fy_units($coverage,$rpm){
  $ids=['7792311754','3572313419','5017324239','5223365459','6368539121','7554015324','6240933652','6568236715','8238832024','5255155049','5798080525'];
  $spec=[];$i=0; foreach($ids as $id){$spec[$id]=['request_rpm'=>max(.03,$rpm*(1.35-$i*.07)),'requests'=>5000+$i*2500,'coverage'=>max(.15,min(.99,$coverage+($i%3-.5)*.025))];$i++;}
  return go_test_unit_rows($spec);
}
mt_srand(420042);
$regimes=['manual_fixed'];
$fail=[];$counts=[];
for($i=0;$i<600;$i++){
  $irpm=mt_rand(25,90)/100; $imp=mt_rand(350,900)/100; $peer=mt_rand(500,820)/100; $peerPrice=mt_rand(35,75)/100;
  $coverage=mt_rand(35,96)/100; $stale=mt_rand(0,9)===0; $connected=mt_rand(0,39)!==0;
  $today=go_test_day(1000,$imp,$irpm,$stale?360:1430);
  $hist=go_test_history(8,1000,$peer,$peerPrice);
  $d=fy_decide(['connected'=>$connected,'intraday'=>array_merge($hist,['2026-09-20'=>$today]),'unit_rows'=>$connected?fy_units($coverage,$irpm):[]]);
  $r=$d['regime']??'';$counts[$r]=($counts[$r]??0)+1;
  if(!in_array($r,$regimes,true))$fail[]="#$i invalid regime $r";
  if(($d['supply_bias']??-1)!==0)$fail[]="#$i financial supply bias {$d['supply_bias']}";
  if(isset($d['tier_floor']))$fail[]="#$i decision still carries a dead tier_floor";
  foreach(['reach','premium','standard','deep','completion'] as $t){
    $lookahead=(float)($d['tier_lookahead'][$t]??0);
    if($lookahead!==1.0)$fail[]="#$i financial lookahead $t = $lookahead";
  }
  $pacing=(float)($d['pacing_scale']??0);
  if($pacing!==1.0)$fail[]="#$i financial pacing $pacing";
  // Critical invariant: a delivery deficit at viable price cannot use negative urgency.
  if($connected && $irpm>=.18 && $imp<6.0 && ($d['supply_bias']??0)<0)$fail[]="#$i deficit negative bias";
}
echo json_encode(['cases'=>600,'regimes'=>$counts,'failures'=>array_slice($fail,0,50),'failureCount'=>count($fail)],JSON_PRETTY_PRINT),"\n";
exit($fail?1:0);
