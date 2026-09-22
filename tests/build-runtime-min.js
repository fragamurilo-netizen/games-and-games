/**
 * Build the production copy of the ad runtime.
 *
 *     node tests/build-runtime-min.js
 *
 * The runtime is printed INLINE in <head> on every monetizable pageview, so
 * every byte of it is re-sent with every HTML document and parsed before the
 * body. The documented source is deliberately comment-heavy — that is how the
 * engine stays auditable — but those comments are pure cost in production.
 *
 * This writes assets/js/go-ads-runtime.min.js: the same program with comments
 * and leading indentation removed. It is NOT a minifier. It never renames an
 * identifier, never removes a semicolon, never reorders a statement and never
 * touches anything inside a string or a regular expression. If it cannot parse
 * something unambiguously it leaves it alone.
 *
 * inc/ads/assets.php uses the generated file only when it is at least as new as
 * the source, so a forgotten rebuild degrades to shipping the documented file
 * rather than to shipping stale code. tests/static-integrity.php fails when the
 * two drift, so a normal test run catches it.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const SOURCE = path.join(__dirname, '..', 'assets', 'js', 'go-ads-runtime.js');
const TARGET = path.join(__dirname, '..', 'assets', 'js', 'go-ads-runtime.min.js');
const LEAN_TARGET = path.join(__dirname, '..', 'assets', 'js', 'go-ads-runtime.lean.js');

/**
 * Drop the operator surface and put its stubs back in its place.
 *
 * The runtime is inlined into every HTML document, so inspect(), explain() and
 * the diagnostic snapshot are re-sent and re-parsed on every pageview by every
 * reader — and an anonymous reader can never call any of them. This produces
 * the copy the public gets. The administrator still receives the full file, so
 * nothing an operator relies on disappears from the site; it disappears from
 * the critical path of people who were never going to use it.
 *
 * Marker-driven on purpose: the boundary is declared in the runtime next to
 * the code it covers, so moving that code cannot silently change what ships.
 * A missing or unbalanced marker is a build failure, never a silent full copy.
 */
function leanVariant(source) {
  const start = source.indexOf('  /*\n   * @lean:strip-start');
  const endMark = '  /* @lean:strip-end */';
  const end = source.indexOf(endMark);
  const stubStart = source.indexOf('  /* @lean:stub');
  const stubEnd = source.indexOf('  @lean:stub-end */');
  if (start === -1 || end === -1 || stubStart === -1 || stubEnd === -1 || end < start || stubEnd < stubStart) {
    throw new Error('Marcadores @lean ausentes ou fora de ordem em go-ads-runtime.js');
  }
  const stub = source.slice(stubStart + '  /* @lean:stub'.length, stubEnd);
  return source.slice(0, start) + stub + source.slice(stubEnd + '  @lean:stub-end */'.length);
}

/**
 * Strip comments without touching strings, template literals or regexes.
 *
 * The only genuinely ambiguous character in JavaScript lexing is `/`: it starts
 * a regex in expression position and a division otherwise. We resolve it the
 * standard way, from the last significant token.
 */
function stripComments(source) {
  let out = '';
  let i = 0;
  const n = source.length;
  let lastSignificant = '';

  const regexAllowedAfter = /^(?:return|typeof|instanceof|in|of|new|delete|void|throw|case|do|else|yield|await)$/;

  while (i < n) {
    const c = source[i];
    const d = source[i + 1];

    /* Line comment. */
    if (c === '/' && d === '/') {
      const end = source.indexOf('\n', i);
      i = end === -1 ? n : end;
      continue;
    }
    /* Block comment. */
    if (c === '/' && d === '*') {
      const end = source.indexOf('*/', i + 2);
      if (end === -1) throw new Error('Unterminated block comment');
      /* A comment between two tokens must not glue them together. */
      if (out.length && !/\s$/.test(out)) out += ' ';
      i = end + 2;
      continue;
    }
    /* String or template literal. */
    if (c === '"' || c === "'" || c === '`') {
      const quote = c;
      out += c; i++;
      while (i < n) {
        if (source[i] === '\\') { out += source[i] + source[i + 1]; i += 2; continue; }
        out += source[i];
        if (source[i] === quote) { i++; break; }
        i++;
      }
      lastSignificant = 'string';
      continue;
    }
    /* Regular expression literal. */
    if (c === '/') {
      const allowed = lastSignificant === '' ||
        /[({[,;:!&|?+\-*%=<>^~]$/.test(lastSignificant) ||
        regexAllowedAfter.test(lastSignificant);
      if (allowed) {
        out += c; i++;
        let inClass = false;
        while (i < n) {
          const ch = source[i];
          if (ch === '\\') { out += ch + source[i + 1]; i += 2; continue; }
          if (ch === '[') inClass = true;
          else if (ch === ']') inClass = false;
          else if (ch === '/' && !inClass) { out += ch; i++; break; }
          else if (ch === '\n') throw new Error('Unterminated regex literal');
          out += ch; i++;
        }
        while (i < n && /[a-z]/.test(source[i])) { out += source[i]; i++; }
        lastSignificant = 'regex';
        continue;
      }
    }
    if (!/\s/.test(c)) lastSignificant = /[A-Za-z0-9_$]/.test(c) ? (/[A-Za-z0-9_$]$/.test(lastSignificant) ? lastSignificant + c : c) : c;
    out += c;
    i++;
  }
  return out;
}

/**
 * The same lexer again, but keeping the boundary between code and literals.
 *
 * squeezeSpaces() below must never look inside a string, a template literal or
 * a regular expression, so the second pass needs to know where each one starts
 * and ends rather than working on one flat string.
 */
function lexChunks(source) {
  const chunks = [];
  let code = '';
  let i = 0;
  const n = source.length;
  let lastSignificant = '';
  const regexAllowedAfter = /^(?:return|typeof|instanceof|in|of|new|delete|void|throw|case|do|else|yield|await)$/;
  const flush = () => { if (code) { chunks.push({ kind: 'code', text: code }); code = ''; } };

  while (i < n) {
    const c = source[i];
    if (c === '"' || c === "'" || c === '`') {
      flush();
      const quote = c;
      let literal = c; i++;
      while (i < n) {
        if (source[i] === '\\') { literal += source[i] + source[i + 1]; i += 2; continue; }
        literal += source[i];
        if (source[i] === quote) { i++; break; }
        i++;
      }
      chunks.push({ kind: 'literal', text: literal });
      lastSignificant = 'string';
      continue;
    }
    if (c === '/') {
      const allowed = lastSignificant === '' ||
        /[({[,;:!&|?+\-*%=<>^~]$/.test(lastSignificant) ||
        regexAllowedAfter.test(lastSignificant);
      if (allowed) {
        flush();
        let literal = c; i++;
        let inClass = false;
        while (i < n) {
          const ch = source[i];
          if (ch === '\\') { literal += ch + source[i + 1]; i += 2; continue; }
          if (ch === '[') inClass = true;
          else if (ch === ']') inClass = false;
          else if (ch === '/' && !inClass) { literal += ch; i++; break; }
          else if (ch === '\n') throw new Error('Unterminated regex literal');
          literal += ch; i++;
        }
        while (i < n && /[a-z]/.test(source[i])) { literal += source[i]; i++; }
        chunks.push({ kind: 'literal', text: literal });
        lastSignificant = 'regex';
        continue;
      }
    }
    if (!/\s/.test(c)) lastSignificant = /[A-Za-z0-9_$]/.test(c) ? (/[A-Za-z0-9_$]$/.test(lastSignificant) ? lastSignificant + c : c) : c;
    code += c;
    i++;
  }
  flush();
  return chunks;
}

/*
 * Characters that can never need a space on the side they sit on.
 *
 * `+` and `-` are deliberately absent: dropping the space in `a + +b` or
 * `a - -b` would produce `a++b` / `a--b`, a different program. `/` is absent
 * too, because `a / /re/` would collapse into a line comment. Everything left
 * is punctuation that cannot merge with its neighbour into another token, and
 * a space is removed only when at least one SIDE of it is one of these — so
 * `case 1:`, `else if`, `new Set` and `k in obj` all keep the space that
 * separates two words.
 */
const SAFE_ADJACENT = /[{}()[\];,:?<>=!&|*%^~.]/;

/** Collapse redundant whitespace inside code, never inside a literal. */
function squeezeSpaces(text) {
  let out = text.replace(/[ \t]+/g, ' ');
  let previous;
  do {
    previous = out;
    out = out.replace(/([^\s]) ([^\s])/g, (match, left, right) =>
      (SAFE_ADJACENT.test(left) || SAFE_ADJACENT.test(right)) ? left + right : match);
  } while (out !== previous);
  return out;
}

const source = fs.readFileSync(SOURCE, 'utf8');

/** Trim each line, then squeeze token spacing inside code only. */
function squeeze(stripped) {
  const lines = stripped
    .split('\n')
    .map((line) => line.replace(/[ \t]+$/, '').replace(/^[ \t]+/, ''))
    .filter((line) => line.length)
    .join('\n');
  return lexChunks(lines)
    .map((chunk) => (chunk.kind === 'code' ? squeezeSpaces(chunk.text) : chunk.text))
    .join('')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length)
    .join('\n');
}

/*
 * Second pass: the runtime is inlined into every HTML document, so the bytes
 * the browser has to receive AND parse are paid again on every pageview rather
 * than once per cache lifetime. Stripping comments left one space between
 * every token; most of those spaces carry no meaning. Identifiers are still
 * never renamed, no statement moves and nothing inside a string, template or
 * regex is touched — the generated file stays readable next to the source.
 */
const compact = squeeze(stripComments(source));

const banner = '/* Overdrive ad runtime — generated from go-ads-runtime.js by tests/build-runtime-min.js. Do not edit. */\n';
fs.writeFileSync(TARGET, banner + compact + '\n', 'utf8');

/* A generated file that does not parse must never reach production. */
require('node:vm').compileFunction(compact, [], { filename: 'go-ads-runtime.min.js' });

/* The public copy runs the exact same pipeline, on a source with the operator
 * surface removed. Same lexer, same squeeze, same parse check. */
const leanCompact = squeeze(stripComments(leanVariant(source)));
fs.writeFileSync(LEAN_TARGET, banner + leanCompact + '\n', 'utf8');
require('node:vm').compileFunction(leanCompact, [], { filename: 'go-ads-runtime.lean.js' });

const before = Buffer.byteLength(source);
const after = Buffer.byteLength(banner + compact);
const lean = Buffer.byteLength(banner + leanCompact);
console.log(JSON.stringify({
  source: before,
  generated: after,
  lean: lean,
  leanSavedBytes: after - lean,
  leanSavedPercent: Math.round(((after - lean) / after) * 1000) / 10,
  savedBytes: before - after,
  savedPercent: Math.round(((before - after) / before) * 1000) / 10
}));
