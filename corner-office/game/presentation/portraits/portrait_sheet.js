/* Retratos do elenco. Game Design Bible §5. Nenhum desenho novo: roda depois
 * dos scripts ORIGINAIS do Fight Studio (studio.js, identity.js, appearance.js,
 * renderer.js), extraídos em tempo de execução de studio.cobundle, e usa o mesmo
 * FightAppearance.resolve + FightRenderer.head da transmissão. Cada retrato vira
 * um PNG transparente devolvido à Godot pela ponte do WebView. */
(function () {
  "use strict";
  const W = __CO_PORTRAIT_W__, H = __CO_PORTRAIT_H__;
  const jobs = JSON.parse(document.getElementById("co-portraits").textContent);
  const renderer = new FightRenderer(document.createElement("canvas"));
  const out = document.createElement("canvas");
  out.width = W;
  out.height = H;
  const ctx = out.getContext("2d");
  function send(key, png) {
    if (window.CornerOffice && window.CornerOffice.portrait) window.CornerOffice.portrait(key, png);
    else if (window.ipc) window.ipc.postMessage(JSON.stringify({ type: "portrait", key, png }));
  }
  function done() {
    if (window.CornerOffice && window.CornerOffice.portraitsDone) window.CornerOffice.portraitsDone();
    else if (window.ipc) window.ipc.postMessage(JSON.stringify({ type: "done" }));
  }
  // Recorte do sprite de cabeça (256×320) no enquadramento de retrato.
  function portrait(fighter) {
    const face = FightAppearance.resolve(fighter, CANON, genFace);
    const head = renderer.head(face);
    ctx.clearRect(0, 0, W, H);
    ctx.drawImage(head, 16, 2, 224, 280, 0, 0, W, H);
    return out.toDataURL("image/png");
  }
  window.renderCornerOfficePortrait = portrait;
  let i = 0;
  function step() {
    for (const end = Math.min(jobs.length, i + 6); i < end; i++) {
      let png = "";
      try { png = portrait(jobs[i].fighter); } catch (e) { png = ""; }
      send(jobs[i].key, png);
    }
    if (i < jobs.length) setTimeout(step, 0);
    else done();
  }
  setTimeout(step, 0);
})();
