<?php
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
function p($n){$w=array_fill(0,$n,'palavra');return '<p>'.implode(' ',$w).'</p>';}
function h(){return '<h2>Subtitulo editorial</h2>';}
function fig(){return '<figure><img src="x.jpg"><figcaption>Legenda</figcaption></figure>';}
$cases=[];
$cases['short-4x70']=p(70).p(70).p(70).p(70);
$cases['short-media']=p(80).fig().p(80).h().p(80).p(60);
$cases['medium-8x70']=str_repeat(p(70),8);
$cases['medium-sections']=p(80).h().p(70).p(70).fig().h().p(70).p(70).h().p(70).p(70);
$cases['news-3para']=p(90).p(80).p(80);
$cases['news-2para']=p(130).p(130);
foreach($cases as $name=>$html){$x=go_verge_ads_plan_article($html);echo "\n$name body={$x['metrics']['bodyWords']} candidates=".count(array_filter($x['candidates'],fn($c)=>!$c['reasons']))." capacity={$x['totalCapacity']} planned={$x['plannedCount']}\n"; foreach(array_merge($x['prime']?[$x['prime']]:[],$x['selected']) as $s){echo " {$s['placement']} @ {$s['beforeWords']} depth={$s['depth']} score={$s['score']}\n";} }
