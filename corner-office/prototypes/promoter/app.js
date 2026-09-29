/* Presentation only: every contract, matchup, ranking and financial result comes from Godot. */
"use strict";
const $ = id => document.getElementById(id);
const esc = value => String(value ?? "").replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money = value => new Intl.NumberFormat('pt-BR',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(value || 0);
const date = d => d?.year ? `${String(d.day).padStart(2,'0')}/${String(d.month).padStart(2,'0')}/${d.year}` : '—';
const record = f => `${f.record.wins}–${f.record.losses}–${f.record.draws}`;
const tabs = [['home','Início'],['fighters','Lutadores'],['events','Eventos'],['market','Mercado'],['organization','Organização']];
const reasonLabels = {
 INVALID_MATCHUP:'Escolha dois atletas diferentes.', EVENT_CLOSED:'O evento precisa estar em planejamento e no futuro.',
 SEX_MISMATCH:'As divisões masculina e feminina são separadas.', DIVISION_MISMATCH:'Os atletas precisam ser da mesma categoria.',
 RETIRED:'Atleta aposentado.',INJURED:'Atleta lesionado.',MEDICAL_SUSPENSION:'Suspensão médica vigente na data do evento.',
 NO_VALID_CONTRACT:'Um atleta não tem contrato válido para este evento.',ALREADY_BOOKED:'Atleta já reservado em data próxima.',
 CARD_TOO_SMALL:'Monte pelo menos seis lutas antes de anunciar.',CARD_FULL:'O card já tem dez lutas.',
 INSUFFICIENT_CASH:'O caixa não cobre os compromissos do evento.',COUNTER_PURSE:'A proposta não foi aceita pelos dois atletas. Aumente a bolsa ou busque outro confronto.',
 BOTH_ACCEPTED:'Os dois atletas aceitaram. Confronto adicionado ao card.',OFFER_UNCHANGED:'Esses termos já foram avaliados. Melhore a oferta para negociar novamente.',
 EXCLUSIVE_CONTRACT:'Atleta com contrato exclusivo em outra organização.',INVALID_CONTRACT:'Confira os valores e o atleta do contrato.',
 INVALID_EVENT:'Evento não encontrado.',EVENT_NOT_ANNOUNCED:'Anuncie o card antes de realizar o evento.'
};
let world=null,tab='home',selectedEvent='',selectedFighter='',filterDivision='',search='',rosterScope='roster',rankingScope='official',quote=null,busy=false;
let matchup={red:'',blue:'',premium:'1'};
const fighter = id => world?.fighters.find(f=>f.id===id);
const division = id => {const d=world?.divisions.find(d=>d.id===id);return d?`${d.name} · ${d.sex==='F'?'feminino':'masculino'}`:id;};
const style = id => world?.styles.find(s=>s.id===id)?.label || id;
const statusName = s => ({planned:'Em montagem',announced:'Anunciado',completed:'Concluído',postponed:'Adiado'}[s]||s);
const reasons = list => (list||[]).map(r=>reasonLabels[r.code]||r.code.replaceAll('_',' ').toLowerCase()).join(' ');
function notice(message,error=false){$('status').textContent=message;$('status').dataset.error=error;}
async function action(name,params={}){
 if(busy)return null;
 busy=true;document.body.classList.add('busy');notice(name==='advance_event'?'Realizando o evento e apurando os resultados…':'Atualizando o escritório…');
 try{
  const response=await fetch('/api/career',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:name,...params})});
  const result=await response.json();
  if(!response.ok)throw new Error(result.error||'Não foi possível concluir a operação.');
  if(result.world)world=result.world;
  if(result.event_id)selectedEvent=result.event_id;
  if(result.quote)quote=result.quote;
  const message=result.error||result.message||(result.proposal?reasons(result.proposal.reasons):reasons(result.reasons))||(result.has_save?'Carreira carregada. Progresso salvo neste computador.':'Pronto para começar sua promoção.');
  notice(message,!result.ok || result.proposal?.outcome==='refused');
  render();return result;
 }catch(e){notice(e.message,true);if(!world)$('content').innerHTML='<h1>Escritório indisponível</h1><p>Inicie o servidor local do Corner Office e atualize esta página.</p>';return null;}
 finally{busy=false;document.body.classList.remove('busy');}
}
function metric(label,value){return `<div class="metric"><small>${esc(label)}</small><strong>${esc(value)}</strong></div>`;}
function button(text,act,id='',cls=''){return `<button class="${cls}" data-action="${act}" data-id="${esc(id)}">${esc(text)}</button>`;}
function portrait(f,large=false){return `<canvas class="${large?'profile-art':'portrait'}" data-fighter="${esc(f.id)}" width="${large?300:100}" height="${large?380:124}" aria-label="Retrato de ${esc(f.name)}"></canvas>`;}
function person(f){return `<div class="person">${portrait(f)}<div>${button(f.name,'profile',f.id,'text-button')}<small>${esc(f.country)} · ${esc(style(f.style))}</small></div></div>`;}
function fighterOptions(ids,selected){return ids.map(f=>`<option value="${esc(f.id)}" ${f.id===selected?'selected':''}>${esc(f.name)} · ${record(f)}</option>`).join('');}
function divisionOptions(selected){return '<option value="">Todas as categorias</option>'+world.divisions.map(d=>`<option value="${d.id}" ${selected===d.id?'selected':''}>${esc(division(d.id))}</option>`).join('');}
function render(){
 $('nav').hidden=!world;
 if(!world){welcome();return;}
 $('season').textContent=`${world.organization.short_name} / ${date(world.date)}`;
 $('nav').innerHTML=tabs.map(([id,label])=>`<button data-tab="${id}" ${tab===id?'aria-current="page"':''}>${label}</button>`).join('');
 const headings={home:['SALA DO PROMOTOR','O próximo capítulo.'],fighters:['SEU ELENCO','Quem entra no cage.'],events:['CALENDÁRIO & MATCHMAKING','A noite começa aqui.'],market:['AGENTES LIVRES','O próximo nome.'],organization:['NOVA PROMOÇÃO','Por trás do espetáculo.']};
 const [kicker,title]=headings[tab];
 $('content').innerHTML=`<p class="eyebrow">${esc(kicker)}</p><h1>${esc(title)}</h1>`+({home:homeView,fighters:fightersView,events:eventsView,market:marketView,organization:orgView}[tab])();
 paintPortraits();
}
function welcome(){
 $('content').innerHTML=`<div class="welcome"><div><p class="eyebrow red">CARREIRA REGIONAL / 2027</p><h1>Construa<br>a próxima<br>grande noite.</h1><p class="intro">Contrate atletas. Negocie os confrontos. Assista às lutas. O resultado dentro do cage muda o seu negócio fora dele.</p><p class="muted">Você começa com 30 atletas e US$ 1,5 milhão. Um mundo com mais de 140 lutadores espera pela sua primeira decisão.</p><form id="start-form"><label>Seed do mundo<input name="seed" type="number" value="2027" min="0" max="2147483647" required></label><button class="primary" type="submit">Abrir minha promoção →</button></form></div><canvas class="welcome-art" width="700" height="900" aria-label="Atleta de MMA da promoção"></canvas></div>`;
 const cv=document.querySelector('.welcome-art');drawStudioFigure(cv.getContext('2d'),700,900,CANON[3],STYLES.studio,{pose:'oficial'});
}
function homeView(){
 const next=world.events.find(e=>e.status==='announced')||world.events.find(e=>e.status==='planned');
 const completed=world.events.filter(e=>e.status==='completed');
 return `<div class="metrics">${metric('Caixa',money(world.organization.cash))}${metric('Atletas no elenco',world.organization.roster.length)}${metric('Eventos realizados',completed.length)}${metric('Calendário',date(world.date))}</div><div class="spread"><section class="hero"><p class="eyebrow">${next?'PRÓXIMO EVENTO':'SUA PRIMEIRA NOITE'}</p><h2>${esc(next?.name||'Uma arena.<br>Dez decisões.') .replace('&lt;br&gt;','<br>')}</h2><p class="muted">${next?`${date(next.date)} · ${esc(next.venue)} · ${next.fight_ids.length} lutas`:'Monte um card de 6 a 10 lutas. Negocie as bolsas e confira os custos antes de anunciar.'}</p><div class="actions">${button(next?'Abrir card →':'Criar primeiro evento →',next?'event':'new-event',next?.id||'','primary')}</div></section><section><p class="eyebrow">A SEMANA NO ESCRITÓRIO</p><h2>O calendário não para.</h2><p class="intro">O avanço do tempo atualiza contratos e realiza os eventos anunciados. Toda noite deixa resultados, um balanço e novas posições nos rankings.</p>${button('Avançar 7 dias','week')}<p class="muted"><small>Seu progresso é salvo após cada decisão.</small></p></section></div><div class="section-title"><h2>Noticiário</h2><span class="eyebrow">FATOS DO SEU MUNDO</span></div>${newsView()}`;
}
function newsView(){return world.news.length?`<ul class="news">${[...world.news].reverse().slice(0,8).map(n=>`<li><small>${date(n.created_at)}</small><h3>${esc(n.headline)}</h3><p>${esc(n.body)}</p></li>`).join('')}</ul>`:'<p class="empty">O noticiário começa com o seu primeiro evento. Nenhuma manchete é gerada antes dos fatos.</p>';}
function filters(){return `<div class="filters"><label>Buscar atleta<input id="search" value="${esc(search)}" placeholder="Nome ou país"></label><label>Categoria<select id="division-filter">${divisionOptions(filterDivision)}</select></label></div>`;}
function filtered(list){const term=search.toLocaleLowerCase();return list.filter(f=>(!filterDivision||f.division===filterDivision)&&`${f.name} ${f.country}`.toLocaleLowerCase().includes(term));}
function rosterTable(list,market=false){return `<div class="table-wrap"><table><thead><tr><th>Atleta</th><th>Categoria</th><th>Cartel</th><th>Bolsa por luta</th><th>${market?'Disponível':'Contrato'}</th></tr></thead><tbody>${filtered(list).map(f=>`<tr><td>${person(f)}</td><td>${esc(division(f.division))}</td><td>${record(f)}</td><td>${money(f.show_money)}</td><td>${market?button('Negociar','profile',f.id):`${f.bouts_remaining} lutas`}</td></tr>`).join('')}</tbody></table></div>${!filtered(list).length?'<p class="empty">Nenhum atleta nesta seleção.</p>':''}`;}
function fightersView(){
 if(selectedFighter)return profileView(fighter(selectedFighter));
 return `<div class="actions">${button('Elenco','roster')}${button('Rankings oficiais','official')}${button('World Combat Index','wci')}</div>${filters()}`+(rosterScope==='roster'?rosterTable(world.fighters.filter(f=>f.organization_id===world.organization.id)):rankingsView());
}
function rankingsView(){
 const org=rankingScope==='wci'?'wci':world.organization.id;
 const tables=world.rankings.filter(r=>r.organization_id===org&&r.entries.length&&(!filterDivision||r.division===filterDivision));
 return `<p class="muted">${org==='wci'?'Comparação mundial independente do elenco da sua promoção.':'Lista oficial de atletas contratados da sua promoção.'} Modelo inicial baseado em resultados e oposição; a avaliação completa da bíblia ainda será ampliada.</p>`+tables.map(r=>`<div class="section-title"><h2>${esc(division(r.division))}</h2><small>${date(r.snapshot_date)}</small></div><div class="table-wrap"><table><thead><tr><th>Posição</th><th>Atleta</th><th>Cartel</th></tr></thead><tbody>${r.entries.slice(0,15).map((id,i)=>{const f=fighter(id);return `<tr><td>${String(i+1).padStart(2,'0')}</td><td>${person(f)}</td><td>${record(f)}</td></tr>`;}).join('')}</tbody></table></div>`).join('');
}
function marketView(){if(selectedFighter)return profileView(fighter(selectedFighter));return '<p class="intro">Atletas livres para uma proposta de quatro lutas. A bolsa de referência é calculada pelo mercado da simulação.</p>'+filters()+rosterTable(world.fighters.filter(f=>!f.organization_id),true);}
function profileView(f){
 if(!f)return '<p>Atleta não encontrado.</p>';
 const own=f.organization_id===world.organization.id,canSign=own||!f.organization_id;
 return `${button('← Voltar à lista','back-list')}<div class="profile-head">${portrait(f,true)}<div><p class="eyebrow">${esc(division(f.division))}</p><h2>${esc(f.name)}</h2><p>${esc(f.country)} · ${esc(style(f.style))}</p><strong>${record(f)}</strong></div></div><div class="profile-data"><div><small>Altura / envergadura</small><strong>${f.height_cm} / ${f.reach_cm} cm</strong></div><div><small>Bolsa de referência</small><strong>${money(f.show_money)}</strong></div><div><small>Contrato restante</small><strong>${f.bouts_remaining} lutas</strong></div><div><small>Repouso médico até</small><strong>${date(f.suspension)}</strong></div></div>${canSign?`<div class="section-title"><h2>${own?'Renovar contrato':'Proposta de contrato'}</h2></div><p class="muted">Quatro lutas, 18 meses. Bônus de vitória: 50% da bolsa. Valores em US$.</p><form id="contract-form" data-id="${f.id}"><div class="form-row"><label>Bolsa por apresentação<input name="show_money" type="number" min="1" max="10000000" value="${f.show_money}" required></label><label>Luvas na assinatura<input name="signing_bonus" type="number" min="0" max="10000000" value="0" required></label></div><button class="primary" type="submit">Enviar proposta de contrato</button></form>`:'<p class="empty">Atleta contratado por outra promoção.</p>'}`;
}
function eventsView(){
 const ev=world.events.find(e=>e.id===selectedEvent)||world.events.at(-1);if(ev)selectedEvent=ev.id;
 return `<details id="create-details" ${!world.events.length?'open':''}><summary>Criar evento</summary><form id="event-form"><div class="form-row"><label>Nome do evento<input name="name" maxlength="80" value="Noite de Combate ${world.events.length+1}" required></label><label>Dias de preparação<input name="days" type="number" min="14" max="120" value="42" required></label></div><button class="primary" type="submit">Criar card</button></form></details><div class="event-layout"><aside class="event-list" aria-label="Eventos">${[...world.events].reverse().map(e=>`<button data-action="event" data-id="${e.id}" aria-pressed="${e.id===selectedEvent}">${esc(e.name)}<small>${date(e.date)} · ${statusName(e.status)}</small></button>`).join('')}</aside><section>${ev?eventDetail(ev):'<p class="empty">Crie um evento para começar a montar o card.</p>'}</section></div>`;
}
function eventDetail(ev){
 const finance=ev.status==='completed'?ev.actual:ev.projected;
 return `<div class="card-head"><p class="eyebrow">${date(ev.date)} / ${esc(ev.city)} / <span class="red">${statusName(ev.status)}</span></p><h2>${esc(ev.name)}</h2><small>${esc(ev.venue)} · ${ev.fights.length} lutas</small></div>${ev.fights.map((f,i)=>boutView(f,i)).join('')}${ev.status==='postponed'?button('Reagendar para daqui a 60 dias','reschedule',ev.id):''}${ev.status==='planned'?matchmaker(ev):''}${finance?.costs?`<div class="metrics">${metric(ev.status==='completed'?'Receita realizada':'Receita prevista',money(finance.revenue))}${metric(ev.status==='completed'?'Custos pagos':'Custo máximo previsto',money(finance.costs))}${metric('Resultado operacional',money(finance.margin))}</div>`:''}<div class="actions">${ev.status==='planned'?button('Anunciar card','announce',ev.id,'primary'):ev.status==='announced'?button('Avançar até o evento e simular','run-event',ev.id,'primary'):button('Ver balanço da noite','finance',ev.id)}</div>${ev.status==='planned'?'<p class="muted"><small>É preciso ter de 6 a 10 lutas e caixa para cobrir os custos. O anúncio fecha o card.</small></p>':''}${ev.status==='completed'?scorecards(ev):''}`;
}
function boutView(f,i){
 const a=fighter(f.red),b=fighter(f.blue),done=f.status==='completed';
 const method={submission:'Finalização',ko_tko:'KO / TKO',decision:'Decisão',draw:'Empate'}[f.method]||f.method;
 return `<article class="bout"><div class="bout-num">${String(i+1).padStart(2,'0')}</div><div class="bout-detail"><small>${esc(division(f.division))}${f.slot==='main_event'?' / LUTA PRINCIPAL':''}</small><strong>${esc(a.name)} <span class="muted">×</span> ${esc(b.name)}</strong>${done?`<small>${esc(f.winner_id?fighter(f.winner_id).name:'Empate')} · ${esc(method)} · R${f.round} ${Math.floor(f.time_s/60)}:${String(f.time_s%60).padStart(2,'0')}</small>`:''}</div><div class="actions">${done?`<a class="button" href="../fight-lab/broadcast.html?career_fight=${encodeURIComponent(f.id)}">Assistir à luta ↗</a>`:world.events.find(e=>e.id===selectedEvent)?.status==='planned'?button('Retirar','remove-bout',f.id):'<span class="tag">CONFIRMADO</span>'}</div></article>`;
}
function matchmaker(ev){
 const booked=new Set(ev.fights.flatMap(f=>[f.red,f.blue]));
 const available=world.fighters.filter(f=>f.organization_id===world.organization.id&&!booked.has(f.id));
 if(!available.some(f=>f.id===matchup.red))matchup.red=available[0]?.id||'';
 const opposite=available.filter(f=>f.id!==matchup.red&&f.division===fighter(matchup.red)?.division);
 if(!opposite.some(f=>f.id===matchup.blue))matchup.blue=opposite[0]?.id||'';
 return `<div class="section-title"><h2>Negociar confronto</h2></div><form id="match-form"><div class="form-row"><label>Corner vermelho<select id="match-red" name="red">${fighterOptions(available,matchup.red)}</select></label><label>Corner azul · mesma categoria<select id="match-blue" name="blue">${fighterOptions(opposite,matchup.blue)}</select></label><label>Oferta de bolsa<select id="premium" name="premium"><option value="1" ${matchup.premium==='1'?'selected':''}>Contrato atual · 1×</option><option value="1.5" ${matchup.premium==='1.5'?'selected':''}>Aumentar 50% · 1,5×</option><option value="2" ${matchup.premium==='2'?'selected':''}>Dobrar oferta · 2×</option></select></label></div><div class="actions"><button type="submit">Avaliar confronto</button>${button('Enviar proposta','propose',ev.id,'primary')}</div></form>${quote?quoteView():''}`;
}
function quoteView(){return `<div class="quote"><div class="metrics">${metric('Encaixe esportivo',Math.round(quote.sporting_fit)+'/100')}${metric('Apelo comercial',Math.round(quote.commercial_fit)+'/100')}${metric('Aceitação vermelho',Math.round((quote.acceptance[matchup.red]||0)*100)+'%')}${metric('Aceitação azul',Math.round((quote.acceptance[matchup.blue]||0)*100)+'%')}</div><p>Compromisso máximo de bolsas: <strong>${money(quote.projected_cost)}</strong></p><p>${quote.eligible?'Elegível. As chances individuais não garantem que ambos aceitem.':esc(reasons(quote.reasons))}</p></div>`;}
function scorecards(ev){return `<details><summary>Cartões dos juízes e detalhes dos resultados</summary>${ev.fights.map(f=>`<h3>${esc(fighter(f.red).name)} × ${esc(fighter(f.blue).name)}</h3><p>${esc(f.detail)}</p><pre>${esc(JSON.stringify(f.scorecards,null,2))}</pre>`).join('')}</details>`;}
const lineLabels={gate:'Bilheteria',media:'Direitos de transmissão',sponsors:'Patrocínios',purses:'Bolsas dos atletas',production:'Produção',venue:'Arena',travel:'Viagens',officials:'Arbitragem',marketing:'Marketing'};
function orgView(){
 const completed=world.events.filter(e=>e.status==='completed');
 const ev=completed.find(e=>e.id===selectedEvent)||completed.at(-1);
 return `<div class="metrics">${metric('Caixa',money(world.organization.cash))}${metric('Sede',world.organization.base_city)}${metric('Reputação',world.organization.reputation+'/100')}</div><p class="intro">${esc(world.organization.name)}. Os custos e receitas de cada noite são lançados uma única vez, após a conclusão de todas as lutas.</p>${completed.length?`<label>Balanço do evento<select id="finance-event">${completed.map(e=>`<option value="${e.id}" ${ev.id===e.id?'selected':''}>${esc(e.name)} · ${date(e.date)}</option>`).join('')}</select></label>${statement(ev)}`:'<p class="empty">O primeiro balanço será disponibilizado após seu evento.</p>'}<div class="section-title"><h2>Seu arquivo de carreira</h2></div><p class="muted">O save é gravado pelo motor a cada decisão. Você pode fechar e voltar a este endereço para continuar.</p>${button('Nova carreira…','reset')}`;
}
function statement(ev){const a=ev.actual;return `<div class="statement"><p class="eyebrow">RESULTADO OPERACIONAL / ${date(ev.date)}</p><h2>${esc(ev.name)}</h2><table><tbody>${['revenue','costs'].map(group=>`<tr><th colspan="2">${group==='revenue'?'Receitas':'Custos'}</th></tr>${Object.entries(a.lines[group]).map(([k,v])=>`<tr><td>${esc(lineLabels[k]||k)}</td><td>${money(v)}</td></tr>`).join('')}`).join('')}<tr class="total"><td>Resultado da noite</td><td>${money(a.margin)}</td></tr></tbody></table><p><small>${a.attendance} presentes · audiência estimada ${a.audience}</small></p></div>`;}
function paintPortraits(){document.querySelectorAll('canvas[data-fighter]').forEach(cv=>{const f=fighter(cv.dataset.fighter);const face=FightAppearance.resolve(f,CANON,genFace);drawFace(cv.getContext('2d'),cv.width,cv.height,face,STYLES.studio);});}
function readMatch(){matchup={red:$('match-red')?.value||'',blue:$('match-blue')?.value||'',premium:$('premium')?.value||'1'};return {event_id:selectedEvent,red:matchup.red,blue:matchup.blue,premium:Number(matchup.premium)};}
document.addEventListener('click',async e=>{
 const nav=e.target.closest('[data-tab]');if(nav){tab=nav.dataset.tab;selectedFighter='';quote=null;render();return;}
 const b=e.target.closest('[data-action]');if(!b||busy)return;const id=b.dataset.id;
 switch(b.dataset.action){
 case 'new-event':tab='events';render();$('create-details').open=true;break;
 case 'event':tab='events';selectedEvent=id;quote=null;matchup={red:'',blue:'',premium:'1'};render();break;
 case 'reschedule':await action('reschedule',{event_id:id,days:60});break;
 case 'week':await action('advance_week');break;
 case 'announce':await action('announce',{event_id:id});break;
 case 'run-event':await action('advance_event',{event_id:id});break;
 case 'remove-bout':quote=null;await action('remove_bout',{fight_id:id});break;
 case 'propose':quote=null;await action('propose',readMatch());break;
 case 'profile':selectedFighter=id;if(!['fighters','market'].includes(tab))tab='fighters';render();break;
 case 'back-list':selectedFighter='';render();break;
 case 'roster':rosterScope='roster';render();break;
 case 'official':case 'wci':rosterScope='rankings';rankingScope=b.dataset.action;render();break;
 case 'finance':tab='organization';selectedEvent=id;render();break;
 case 'reset':$('reset-dialog').showModal();break;
 }
});
document.addEventListener('submit',async e=>{
 const form=e.target;if(!['start-form','new-form','event-form','match-form','contract-form'].includes(form.id))return;
 e.preventDefault();const data=Object.fromEntries(new FormData(form));
 if(form.id==='start-form'||form.id==='new-form'){const result=await action('new',{seed:Number(data.seed),replace:form.id==='new-form'});if(result?.ok){$('reset-dialog').close();tab='home';selectedFighter='';selectedEvent='';render();}}
 if(form.id==='event-form'){quote=null;await action('create_event',{name:data.name,days:Number(data.days)});}
 if(form.id==='match-form')await action('evaluate',readMatch());
 if(form.id==='contract-form'){const result=await action('negotiate',{fighter_id:form.dataset.id,show_money:Number(data.show_money),signing_bonus:Number(data.signing_bonus)});if(result?.counter_show){document.querySelector('[name=show_money]').value=result.counter_show;notice(`Contraproposta: ${money(result.counter_show)} por apresentação. Revise e envie se concordar.`);}}
});
document.addEventListener('change',e=>{
 if(e.target.id==='division-filter'){filterDivision=e.target.value;render();}
 if(['match-red','match-blue','premium'].includes(e.target.id)){readMatch();quote=null;render();}
 if(e.target.id==='finance-event'){selectedEvent=e.target.value;render();}
});
document.addEventListener('input',e=>{if(e.target.id==='search'){const cursor=e.target.selectionStart;search=e.target.value;render();$('search').focus();$('search').setSelectionRange(cursor,cursor);}});
$('cancel-reset').onclick=()=>$('reset-dialog').close();
action('state');
