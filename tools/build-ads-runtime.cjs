/**
 * Generate theme/assets/js/go-ads-runtime.min.js and .lean.js from the
 * documented source, go-ads-runtime.js.
 *
 *   NODE_PATH=<dir with terser> node tools/build-ads-runtime.cjs [--check]
 *
 * - .min.js  full engine, including the operator surface (inspect/explain);
 *            served to logged-in administrators.
 * - .lean.js the block between @lean:strip-start and @lean:strip-end is
 *            replaced by the stubs inside the @lean:stub comment; served to
 *            the public.
 *
 * Both outputs are inlined into HTML by inc/ads/assets.php, which refuses any
 * body containing "<" followed by a letter, "/", "!" or "?" (HTML filters such
 * as Burst Statistics rewrite those). A space is inserted after every such
 * "<" (they are comparison operators after minification) and the result is
 * re-parsed to prove nothing else changed.
 */
const fs = require('fs');
const path = require('path');
const { minify } = require('terser');
const vm = require('vm');

const dir = path.join(__dirname, '..', 'theme', 'assets', 'js');
const source = fs.readFileSync(path.join(dir, 'go-ads-runtime.js'), 'utf8');
const version = (/var VERSION = '([^']+)'/.exec(source) || [])[1] || 'unknown';

function leanSource(src) {
  const markStart = src.indexOf('@lean:strip-start');
  const blockStart = src.lastIndexOf('/*', markStart);
  const endMark = '/* @lean:strip-end */';
  const blockEnd = src.indexOf(endMark, markStart);
  if (markStart < 0 || blockStart < 0 || blockEnd < 0) throw new Error('lean markers not found');
  let out = src.slice(0, blockStart) + src.slice(blockEnd + endMark.length);
  const stubOpen = out.indexOf('/* @lean:stub');
  const stubClose = out.indexOf('@lean:stub-end */');
  if (stubOpen < 0 || stubClose < 0) throw new Error('lean stub not found');
  out = out.slice(0, stubOpen) + out.slice(stubOpen + '/* @lean:stub'.length, stubClose) + out.slice(stubClose + '@lean:stub-end */'.length);
  return out;
}

async function build(src, label) {
  const result = await minify(src, { ecma: 5, compress: { passes: 2 }, mangle: true, format: { comments: false } });
  let code = result.code.replace(/<([A-Za-z!\/?])/g, '< $1');
  new vm.Script(code); // must still parse
  if (/<[a-z!\/?]/i.test(code)) throw new Error(label + ': unsafe "<" sequence survived');
  const header = `/* Overdrive ad runtime ${version}${label === 'lean' ? ' lean' : ''} -- generated from go-ads-runtime.js by tools/build-ads-runtime.cjs. Do not edit. */\n`;
  return header + code + '\n';
}

(async () => {
  const check = process.argv.includes('--check');
  const outputs = { 'go-ads-runtime.min.js': await build(source, 'full'), 'go-ads-runtime.lean.js': await build(leanSource(source), 'lean') };
  let stale = 0;
  for (const [file, code] of Object.entries(outputs)) {
    const target = path.join(dir, file);
    const current = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
    if (check) {
      if (current !== code) { stale++; console.log(`${file}: stale`); } else console.log(`${file}: up to date`);
    } else {
      fs.writeFileSync(target, code);
      console.log(`${file}: ${code.length} bytes (was ${current.length})`);
    }
  }
  if (check && stale) process.exit(1);
})().catch((e) => { console.error(e); process.exit(1); });
