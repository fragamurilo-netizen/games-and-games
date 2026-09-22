<?php
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

function gf_words($n,$seed='w') { $a=[]; for($i=0;$i<$n;$i++) $a[]=$seed.$i; return implode(' ',$a); }
function gf_article($seed) {
    mt_srand(91001 + $seed * 7919);
    $target = mt_rand(200, 2800);
    $html=''; $words=0; $block=0;
    while($words < $target && $block < 80) {
        $block++;
        $type = mt_rand(1,100);
        $remain = $target - $words;
        if ($type <= 55) {
            $n = min($remain, mt_rand(18,95)); if($n<1) break;
            $html .= '<p>'.gf_words($n,'p').'.</p>'; $words += $n;
        } elseif ($type <= 66 && $remain > 30) {
            $html .= '<h2>Seção '.$block.'</h2>';
        } elseif ($type <= 76 && $remain > 40) {
            $n = min($remain, mt_rand(35,120));
            $li = max(2, min(8, mt_rand(2,7))); $each=max(5,(int)floor($n/$li));
            $html.='<ul>'; $added=0;
            for($j=0;$j<$li && $added<$n;$j++){ $take=min($each,$n-$added); $html.='<li>'.gf_words($take,'l').'</li>'; $added+=$take; }
            $html.='</ul>'; $words += $added;
        } elseif ($type <= 84) {
            $html .= '<figure><img src="x'.$block.'.jpg" alt="imagem"><figcaption>Imagem editorial.</figcaption></figure>';
        } elseif ($type <= 90) {
            $html .= '<div class="go-cta"><a href="#">CTA protegido</a></div>';
        } elseif ($type <= 94) {
            $html .= '<blockquote>'.gf_words(mt_rand(12,35),'q').'</blockquote>';
        } elseif ($type <= 97) {
            $html .= '<div class="wp-block-group"><div class="wp-block-group__inner-container"><p>'.gf_words(min($remain,mt_rand(18,55)),'g').'</p></div></div>';
            $words += min($remain,55); // rough target only; planner calculates exact.
        } else {
            $html .= '<iframe src="https://example.test/embed/'.$block.'"></iframe>';
        }
    }
    if ($words < $target) { $n=$target-$words; $html.='<p>'.gf_words($n,'z').'</p>'; }
    return [$html,$target];
}

$fail=[]; $stats=['cases'=>0,'plannerLoss'=>0,'unrecoverable'=>0,'maxLoss'=>0,'capacity7'=>0,'capacity7Under'=>0,'zeroUnexpected'=>0];
$lossCases=[];
for($seed=1;$seed<=600;$seed++) {
    [$html,$target]=gf_article($seed);
    $a=go_verge_ads_plan_article($html); $b=go_verge_ads_plan_article($html);
    $stats['cases']++;
    $checks=[
      ['determinism',$a['plannedCount']===$b['plannedCount'] && $a['renderedCount']===$b['renderedCount']],
      ['planned<=capacity',$a['plannedCount'] <= $a['totalCapacity']],
      ['rendered>=planned',$a['renderedCount'] >= $a['plannedCount']],
      ['rendered<=7',$a['renderedCount'] <= 7],
      ['reserve<=2',$a['reserveCount'] <= 2],
      ['exact rendered',$a['renderedCount'] === $a['plannedCount'] + $a['reserveCount']],
      ['short safe',($a['metrics']['bodyWords']>=240 || $a['plannedCount']===0)],
    ];
    $all=array_merge($a['prime']?[ $a['prime'] ]:[], (array)$a['selected'], (array)$a['reserves']);
    $pl=[];$pos=[];
    foreach($all as $u){$pl[]=$u['placement'];$pos[]=$u['position'];}
    $checks[]=['unique placement',count($pl)===count(array_unique($pl))];
    $checks[]=['unique pos',count($pos)===count(array_unique($pos))];
    foreach($checks as [$name,$ok]) if(!$ok) $fail[]="seed=$seed $name words={$a['metrics']['bodyWords']} cap={$a['totalCapacity']} plan={$a['plannedCount']} render={$a['renderedCount']}";
    $loss=max(0,$a['totalCapacity']-$a['plannedCount']);
    $unrec=max(0,$a['totalCapacity']-$a['renderedCount']);
    if($loss>0){$stats['plannerLoss']++;$stats['maxLoss']=max($stats['maxLoss'],$loss);}
    if($unrec>0){$stats['unrecoverable']++;$lossCases[]=['seed'=>$seed,'words'=>$a['metrics']['bodyWords'],'cap'=>$a['totalCapacity'],'plan'=>$a['plannedCount'],'render'=>$a['renderedCount'],'reserve'=>$a['reserveCount'],'eligible'=>count(array_filter($a['candidates'],fn($x)=>empty($x['reasons']))),'sub'=>$a['metrics']['substantial']];}
    if($a['totalCapacity']===7){$stats['capacity7']++; if($a['renderedCount']<7)$stats['capacity7Under']++;}
    if($a['metrics']['bodyWords']>=400 && $a['metrics']['substantial']>=2 && $a['totalCapacity']===0)$stats['zeroUnexpected']++;
}

echo json_encode(['stats'=>$stats,'failures'=>array_slice($fail,0,30),'lossCases'=>array_slice($lossCases,0,50)], JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";
exit($fail?1:0);
