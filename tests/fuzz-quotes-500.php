<?php
if ( 'cli' !== PHP_SAPI ) { exit(1); }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
function qf_words($n,$prefix='w'){ $a=[]; for($i=0;$i<$n;$i++)$a[]=$prefix.$i; return implode(' ',$a); }
function qf_p($n){ return '<p>'.qf_words($n,'p').'.</p>'; }
function qf_q($n){ return '<blockquote><p>'.qf_words($n,'q').'.</p><cite>Fonte</cite></blockquote>'; }
$fail=[]; $pass=0; mt_srand(430043);
for($case=1;$case<=500;$case++){
  $blocks=[]; $total=0; $quoteWords=0; $count=6+($case%7);
  for($i=0;$i<$count;$i++){
    $n=35+mt_rand(0,75); $isQuote=(mt_rand(0,99)<38);
    if($isQuote){$blocks[]=qf_q($n);$quoteWords+=($n+1);$total+=($n+1);} else {$blocks[]=qf_p($n);$total+=$n;}
    if($i>0 && $i%4===0)$blocks[]='<h2>Seção '.$i.'</h2>';
  }
  $html=implode('',$blocks); $plan=go_verge_ads_plan_article($html); $plan2=go_verge_ads_plan_article($html);
  $checks=[];
  $checks[]=['determinismo',$plan['plannedCount']===$plan2['plannedCount'] && $plan['totalCapacity']===$plan2['totalCapacity']];
  $checks[]=['quote words',(int)$plan['metrics']['quoteWords']===$quoteWords];
  $checks[]=['body words',(int)$plan['metrics']['bodyWords']===$total];
  $checks[]=['cap sane',(int)$plan['totalCapacity']>=0 && (int)$plan['totalCapacity']<=7];
  $checks[]=['plan<=cap',(int)$plan['plannedCount']<=(int)$plan['totalCapacity']];
  $checks[]=['render>=plan',(int)$plan['renderedCount']>=(int)$plan['plannedCount']];
  $parsed=go_verge_ads_planner_blocks($html); $inside=0;
  $placements=array_merge($plan['prime']?[$plan['prime']]:[],(array)$plan['selected'],(array)$plan['reserves']);
  foreach($placements as $u){ foreach($parsed as $b){ if(($b['kind']??'')==='quote' && (int)$u['position']>(int)$b['start'] && (int)$u['position']<(int)$b['end'])$inside++; } }
  $checks[]=['not inside quote',$inside===0];
  foreach($checks as [$name,$ok]){ if($ok)$pass++; else $fail[]="case=$case $name total=$total quote=$quoteWords cap={$plan['totalCapacity']} plan={$plan['plannedCount']}"; }
}
echo json_encode(['cases'=>500,'assertions'=>$pass+count($fail),'passed'=>$pass,'failures'=>array_slice($fail,0,40),'failureCount'=>count($fail)],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";
exit($fail?1:0);
