/* Presentation shell only. Uses the ORIGINAL Fight Studio renderer, identity,
   animation sampler and immutable Godot replay. Bible §§6,15,17. */
(async () => {
  const $ = id => document.getElementById(id);
  const json = id => JSON.parse($(id).textContent);
  const read = async path => { const r = await fetch('../../game/content/' + path); if (!r.ok) throw new Error('Conteúdo indisponível.'); return r.json(); };
  const clock = seconds => `${Math.floor(Math.max(0, seconds)/60)}:${String(Math.floor(Math.max(0, seconds)%60)).padStart(2,'0')}`;
  const labels = {completed:'Concluído',landed:'Acertou',missed:'Errou',evaded:'Esquiva',blocked:'Bloqueado',defended:'Defendido',escaped:'Escapou',held:'Controle',threatened:'Tentativa de finalização',tapped:'Desistência',knockdown:'Knockdown',stoppage:'Interrupção'};
  let player, renderer, replay, catalog, arena, appearance, time=0, playing=false, last=0;
  $('back').onclick = () => { if (window.CornerOffice) window.CornerOffice.close(); else if (location.protocol==='file:') window.close(); else location.href='../promoter/'; };
  try {
    const bundled = !!$('co-catalog');
    catalog = bundled ? json('co-catalog') : await read('fight_visuals.json');
    const arenas = bundled ? json('co-arenas') : await read('arena_profiles.json');
    if (bundled) replay=json('co-replay');
    else {
      const id=new URLSearchParams(location.search).get('career_fight');
      if (id) {
        const response=await fetch('/api/career',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'replay',fight_id:id})});
        const data=await response.json(); if (!response.ok || !data.replay) throw new Error(data.error||'Replay indisponível.'); replay=data.replay;
      } else replay=await read('replays/sim_women.json');
    }
    player=new FightReplay.Player(replay,catalog,arenas);
    arena=FightReplay.arenaFor(replay,arenas);
    appearance=Object.fromEntries(replay.fighter_ids.map(id=>[id,FightAppearance.resolve(replay.fighters[id],CANON,genFace)]));
    renderer=new FightRenderer($('fight'));renderer.camera='broadcast';
    $('seek').max=player.duration;
    $('red').textContent=appearance[replay.fighter_ids[0]].name.toUpperCase();
    $('blue').textContent=appearance[replay.fighter_ids[1]].name.toUpperCase();
    function draw() {
      const frame=player.sample(time);renderer.render(frame,arena,appearance);
      $('round').textContent=`R${frame.event.round} / ${replay.scheduled_rounds||3}`;
      $('clock').textContent=clock(frame.event.clock_s);
      $('action').textContent=frame.clip.label;$('outcome').textContent=labels[frame.event.outcome]||frame.event.outcome;
      $('seek').value=time;$('time').textContent=`${clock(time/1000)} / ${clock(player.duration/1000)}`;
      $('result').hidden=time<player.duration || !replay.result;
      if (!$('result').hidden) {
        const result=replay.result;$('result').replaceChildren();
        const name=document.createElement('strong');name.textContent=result.winner_id?appearance[result.winner_id].name:'EMPATE';$('result').append(name);
        const text=document.createElement('p');text.textContent=`${{submission:'FINALIZAÇÃO',decision:'DECISÃO',ko_tko:'KO / TKO',draw:'EMPATE'}[result.method]||result.method} · ${catalog.clips.find(x=>x.id===result.detail)?.label||{unanimous:'Unânime',split:'Dividida',majority:'Majoritária',referee_tko:'Interrupção do árbitro',knockout:'Nocaute'}[result.detail]||result.detail} · R${result.round} ${clock(result.time_s)}`;$('result').append(text);
        for (const card of result.scorecards||[]) { const row=document.createElement('p');row.textContent=`${card.judge_id||'Árbitro'}: ${(card.total||[]).join(' × ')}`;$('result').append(row); }
      }
      document.body.dataset.ready='true';
    }
    const sync=()=>{$('play').textContent=playing?'PAUSAR':'REPRODUZIR';};
    $('play').onclick=()=>{if(time>=player.duration)time=0;playing=!playing;last=0;sync();draw();};
    $('seek').oninput=()=>{time=Number($('seek').value);last=0;draw();};
    $('instant').onclick=()=>{time=player.duration;playing=false;sync();draw();};
    $('camera').onchange=()=>{renderer.camera=$('camera').value;draw();};
    window.pauseCornerOffice=()=>{playing=false;sync();last=0;};
    document.addEventListener('visibilitychange',()=>{if(document.hidden){playing=false;sync();}last=0;});
    const tick=now=>{if(playing){time=Math.min(player.duration,time+(last?now-last:0)*Number($('speed').value));if(time>=player.duration){playing=false;sync();}draw();}last=now;requestAnimationFrame(tick);};
    new ResizeObserver(draw).observe($('fight'));await document.fonts.ready;draw();requestAnimationFrame(tick);
  } catch(error) {$('error').textContent=error.message;$('error').hidden=false;}
})();
