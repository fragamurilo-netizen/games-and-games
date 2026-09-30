/* Retratos do elenco. Game Design Bible §5. Nenhum desenho novo: roda depois
 * dos scripts ORIGINAIS do Fight Studio (studio.js, identity.js, appearance.js,
 * renderer.js), extraídos em tempo de execução de studio.cobundle: mesma
 * FightAppearance.resolve e mesmo drawFace/catálogo da transmissão, no estilo
 * ilustrado "flat" da biblioteca (contorno e cor chapada, legível em avatar).
 * Cada retrato vira um PNG transparente devolvido à Godot pela ponte do WebView;
 * a moldura (fundo, faixa do corner) é desenhada pela Godot. */
(function () {
  "use strict";
  const W = __CO_PORTRAIT_W__, H = __CO_PORTRAIT_H__, STYLE = "__CO_PORTRAIT_STYLE__";
  const jobs = JSON.parse(document.getElementById("co-portraits").textContent);
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
  // Busto em fundo transparente, rosto grande para ler bem em miniatura.
  function portrait(fighter) {
    const face = FightAppearance.resolve(fighter, CANON, genFace);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, W, H);
    drawFace(ctx, W, H, face, STYLES[STYLE] || STYLES.flat, { S: W * 0.365, ox: W / 2, oy: H * 0.49 });
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
