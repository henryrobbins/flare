#!/usr/bin/env python3
"""Side-by-side / diff viewer for extracted FLARE results.

Walks results/<run_id>/<problem>/<a_b>/<artifact>/ and serves a browser UI
that lets you pick (problem, pair, artifact, side) and compare the
extracted Formulation against the ground-truth dataset formulation.

Usage:
    python scripts/review/flare_formulation_reviewer.py -r <run_id> [--port 8080]
"""

import argparse
import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

REPO_ROOT = Path(__file__).resolve().parents[2]


def _problem_sort_key(p: Path):
    m = re.match(r"^p(\d+)$", p.name)
    return int(m.group(1)) if m else float("inf")


def find_entries(results_dir: Path) -> list[dict]:
    """One dict per (problem, pair, artifact) under results_dir."""
    entries: list[dict] = []
    for problem_dir in sorted(results_dir.iterdir(), key=_problem_sort_key):
        if not problem_dir.is_dir():
            continue
        problem = problem_dir.name
        for pair_dir in sorted(problem_dir.iterdir()):
            if not pair_dir.is_dir():
                continue
            m = re.match(r"^([a-z]+)_([a-z]+)$", pair_dir.name)
            if not m:
                continue
            fa, fb = m.group(1), m.group(2)
            for artifact_dir in sorted(pair_dir.iterdir()):
                if not artifact_dir.is_dir():
                    continue
                # Artifact dirs always contain A/ and B/; legacy directly-under
                # a_b/ extractions don't.
                if not (artifact_dir / "A").is_dir():
                    continue
                entries.append(
                    {
                        "problem": problem,
                        "pair": pair_dir.name,
                        "artifact": artifact_dir.name,
                        "fa": fa,
                        "fb": fb,
                    }
                )
    return entries


def read_file(path: Path) -> str:
    try:
        return path.read_text()
    except FileNotFoundError:
        return f"-- FILE NOT FOUND: {path}"


HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Formulation Diff Viewer</title>
<script src="https://cdn.jsdelivr.net/npm/diff@5/dist/diff.min.js"></script>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, sans-serif; display: flex; height: 100vh; overflow: hidden; background: #1e1e1e; color: #d4d4d4; }

/* Sidebar */
#sidebar { width: 280px; min-width: 200px; background: #252526; border-right: 1px solid #3c3c3c; display: flex; flex-direction: column; overflow: hidden; }
#sidebar-header { padding: 10px 12px; font-size: 12px; font-weight: 600; color: #ccc; text-transform: uppercase; letter-spacing: .05em; border-bottom: 1px solid #3c3c3c; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
#pair-list { overflow-y: auto; flex: 1; }
.problem-header { padding: 8px 12px 2px; font-size: 11px; color: #888; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; }
.pair-header { padding: 4px 12px 2px 20px; font-size: 11px; color: #aaa; font-weight: 600; }
.artifact-row { display: flex; align-items: stretch; }
.artifact-label { padding: 4px 0 4px 28px; font-size: 11px; color: #888; flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.page-btn { width: 40px; padding: 4px 6px; cursor: pointer; font-size: 11px; color: #bbb; white-space: nowrap; border: none; background: none; text-align: center; }
.page-btn:hover { background: #2a2d2e; color: #fff; }
.page-btn.active { background: #094771; color: #fff; }
.page-btn + .page-btn { border-left: 1px solid #3c3c3c; }

/* Main */
#main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
#toolbar { display: flex; align-items: center; gap: 10px; padding: 8px 14px; background: #2d2d2d; border-bottom: 1px solid #3c3c3c; }
#toolbar h2 { font-size: 13px; font-weight: 600; color: #ccc; flex: 1; }
.btn { background: #3a3d41; border: 1px solid #555; color: #ccc; padding: 4px 10px; border-radius: 3px; cursor: pointer; font-size: 12px; }
.btn.active { background: #094771; border-color: #1177bb; color: #fff; }
.btn:hover:not(.active) { background: #454545; }

/* Content */
#content { flex: 1; display: flex; overflow: hidden; }
#placeholder { flex: 1; display: flex; align-items: center; justify-content: center; color: #555; font-size: 14px; }

/* Side-by-side panes */
#sbs-view { flex: 1; display: none; overflow: hidden; }
.pane { flex: 1; display: flex; flex-direction: column; overflow: hidden; border-right: 1px solid #3c3c3c; }
.pane:last-child { border-right: none; }
.pane-header { padding: 5px 10px; background: #2d2d2d; border-bottom: 1px solid #3c3c3c; font-size: 11px; color: #aaa; display: flex; gap: 6px; align-items: center; }
.pane-label { font-weight: 600; color: #ddd; margin-right: 4px; }
.pane-body { flex: 1; overflow: auto; }
pre { font-family: 'Menlo', 'Monaco', 'Courier New', monospace; font-size: 12px; line-height: 1.5; padding: 10px; white-space: pre; }

/* Diff view */
#diff-view { flex: 1; overflow: auto; display: none; }
.diff-file-header { padding: 4px 12px; background: #252526; font-size: 12px; font-weight: 600; color: #ccc; border-top: 1px solid #3c3c3c; border-bottom: 1px solid #3c3c3c; }
.diff-hunk { font-family: 'Menlo', 'Monaco', 'Courier New', monospace; font-size: 12px; }
.diff-line { display: flex; line-height: 1.5; }
.diff-line-no { width: 44px; min-width: 44px; text-align: right; padding: 0 8px; color: #555; user-select: none; border-right: 1px solid #3c3c3c; }
.diff-line-content { padding: 0 10px; white-space: pre; flex: 1; }
.diff-add { background: #1a3322; }
.diff-add .diff-line-no { background: #1a3322; }
.diff-add .diff-line-content::before { content: '+'; color: #4ec994; margin-right: 4px; }
.diff-remove { background: #3c1515; }
.diff-remove .diff-line-no { background: #3c1515; }
.diff-remove .diff-line-content::before { content: '-'; color: #f14c4c; margin-right: 4px; }
.diff-equal .diff-line-content::before { content: ' '; margin-right: 4px; }
mark.ci-add    { background: #2ea04326; color: inherit; border-radius: 2px; outline: 1px solid #2ea04366; }
mark.ci-remove { background: #f8514926; color: inherit; border-radius: 2px; outline: 1px solid #f8514966; }
</style>
</head>
<body>
<div id="sidebar">
  <div id="sidebar-header" title=""></div>
  <div id="pair-list"></div>
</div>
<div id="main">
  <div id="toolbar">
    <h2 id="title">Select a formulation</h2>
    <button class="btn active" id="btn-sidebyside" onclick="setMode('sidebyside')">Side by side</button>
    <button class="btn" id="btn-diff" onclick="setMode('diff')">Diff</button>
  </div>
  <div id="content">
    <div id="placeholder">← Select a formulation</div>
    <div id="sbs-view">
      <div style="display:flex;flex:1;height:100%;overflow:hidden;">
        <div class="pane">
          <div class="pane-header"><span class="pane-label">Ground truth</span><span id="label-gt"></span></div>
          <div class="pane-body"><pre id="code-gt"></pre></div>
        </div>
        <div class="pane">
          <div class="pane-header"><span class="pane-label">Result</span><span id="label-res"></span></div>
          <div class="pane-body"><pre id="code-res"></pre></div>
        </div>
      </div>
    </div>
    <div id="diff-view"></div>
  </div>
</div>

<script>
let entries = [];
let mode = 'sidebyside';
let files = {};   // cache keyed by `${problem}/${pair}/${artifact}`
let currentKey = null;

async function init() {
  const res = await fetch('/api/entries');
  entries = await res.json();
  renderSidebar();
}

function btnId(problem, pair, artifact, which) {
  return `btn-${problem}--${pair}--${artifact}--${which}`;
}

function renderSidebar() {
  const el = document.getElementById('pair-list');
  document.getElementById('sidebar-header').textContent = window._resultsName || 'Results';
  let html = '';
  let lastProblem = null;
  let lastPair = null;
  for (const e of entries) {
    if (e.problem !== lastProblem) {
      html += `<div class="problem-header">${e.problem}</div>`;
      lastProblem = e.problem;
      lastPair = null;
    }
    if (e.pair !== lastPair) {
      html += `<div class="pair-header">${e.pair}</div>`;
      lastPair = e.pair;
    }
    html += `<div class="artifact-row">
      <div class="artifact-label" title="${e.artifact}">${e.artifact}</div>
      <button class="page-btn" id="${btnId(e.problem, e.pair, e.artifact, 'A')}"
              onclick="selectPage('${e.problem}','${e.pair}','${e.artifact}','${e.fa}','${e.fb}','A')">${e.fa}</button>
      <button class="page-btn" id="${btnId(e.problem, e.pair, e.artifact, 'B')}"
              onclick="selectPage('${e.problem}','${e.pair}','${e.artifact}','${e.fa}','${e.fb}','B')">${e.fb}</button>
    </div>`;
  }
  el.innerHTML = html;
}

function esc(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

async function selectPage(problem, pair, artifact, fa, fb, which) {
  const pageKey = `${problem}/${pair}/${artifact}/${which}`;
  if (currentKey === pageKey) return;
  currentKey = pageKey;

  document.querySelectorAll('.page-btn').forEach(el => el.classList.remove('active'));
  document.getElementById(btnId(problem, pair, artifact, which)).classList.add('active');

  const fLabel = which === 'A' ? fa : fb;
  document.getElementById('title').textContent = `${problem} / ${pair} / ${artifact} · ${fLabel}`;

  const cacheKey = `${problem}/${pair}/${artifact}`;
  if (!files[cacheKey]) {
    const qs = new URLSearchParams({problem, pair, artifact, fa, fb});
    const res = await fetch('/api/files?' + qs.toString());
    files[cacheKey] = await res.json();
  }
  const f = files[cacheKey];
  const gt   = which === 'A' ? f.gt_a   : f.gt_b;
  const res  = which === 'A' ? f.res_a  : f.res_b;
  const pGt  = which === 'A' ? f.path_gt_a  : f.path_gt_b;
  const pRes = which === 'A' ? f.path_res_a : f.path_res_b;

  document.getElementById('code-gt').textContent  = gt;
  document.getElementById('code-res').textContent = res;
  document.getElementById('label-gt').textContent  = pGt;
  document.getElementById('label-res').textContent = pRes;

  applyMode(gt, res, pGt, pRes);
}

function setMode(m) {
  mode = m;
  ['sidebyside','diff'].forEach(k => document.getElementById('btn-' + k).classList.toggle('active', k === m));
  if (!currentKey) return;
  const [problem, pair, artifact, which] = currentKey.split('/');
  const f = files[`${problem}/${pair}/${artifact}`];
  if (!f) return;
  const gt   = which === 'A' ? f.gt_a   : f.gt_b;
  const res  = which === 'A' ? f.res_a  : f.res_b;
  const pGt  = which === 'A' ? f.path_gt_a  : f.path_gt_b;
  const pRes = which === 'A' ? f.path_res_a : f.path_res_b;
  applyMode(gt, res, pGt, pRes);
}

function applyMode(gt, res, pGt, pRes) {
  document.getElementById('placeholder').style.display = 'none';
  const sbsView  = document.getElementById('sbs-view');
  const diffView = document.getElementById('diff-view');
  if (mode === 'sidebyside') {
    sbsView.style.display  = 'flex';
    diffView.style.display = 'none';
  } else {
    sbsView.style.display  = 'none';
    diffView.style.display = 'block';
    diffView.innerHTML = renderUnifiedDiff(gt, res, pGt, pRes);
  }
}

function inlineCharDiff(oldLine, newLine) {
  const parts = Diff.diffWordsWithSpace(oldLine, newLine);
  let oldHtml = '', newHtml = '';
  for (const p of parts) {
    const t = esc(p.value);
    if (p.added)        newHtml += `<mark class="ci-add">${t}</mark>`;
    else if (p.removed) oldHtml += `<mark class="ci-remove">${t}</mark>`;
    else { oldHtml += t; newHtml += t; }
  }
  return [oldHtml, newHtml];
}

function renderUnifiedDiff(oldText, newText, oldPath, newPath) {
  const changes = Diff.diffLines(oldText, newText);
  let lineOld = 1, lineNew = 1;
  const CONTEXT = 4;

  const lines = [];
  for (const part of changes) {
    const partLines = part.value.replace(/\n$/, '').split('\n');
    for (const line of partLines) {
      if (part.added)        lines.push({ type: 'add',    lineNew: lineNew++, content: line });
      else if (part.removed) lines.push({ type: 'remove', lineOld: lineOld++, content: line });
      else                   lines.push({ type: 'equal',  lineOld: lineOld++, lineNew: lineNew++, content: line });
    }
  }

  for (let i = 0; i < lines.length; ) {
    if (lines[i].type !== 'remove') { i++; continue; }
    let rEnd = i;
    while (rEnd < lines.length && lines[rEnd].type === 'remove') rEnd++;
    let aEnd = rEnd;
    while (aEnd < lines.length && lines[aEnd].type === 'add') aEnd++;
    const removes = lines.slice(i, rEnd);
    const adds    = lines.slice(rEnd, aEnd);
    const pairs   = Math.min(removes.length, adds.length);
    for (let k = 0; k < pairs; k++) {
      const [oldHtml, newHtml] = inlineCharDiff(removes[k].content, adds[k].content);
      removes[k].inlineHtml = oldHtml;
      adds[k].inlineHtml    = newHtml;
    }
    i = aEnd;
  }

  const changed = new Set();
  lines.forEach((l, i) => { if (l.type !== 'equal') changed.add(i); });
  const visible = new Set();
  changed.forEach(i => {
    for (let j = Math.max(0, i - CONTEXT); j <= Math.min(lines.length - 1, i + CONTEXT); j++) visible.add(j);
  });

  let html = `<div class="diff-file-header">--- ${esc(oldPath)}<br>+++ ${esc(newPath)}</div><div class="diff-hunk">`;
  let inHidden = false;
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (!visible.has(i)) {
      if (!inHidden) { html += `<div style="padding:2px 10px;color:#555;font-size:11px;font-family:monospace">@@ ... @@</div>`; inHidden = true; }
      continue;
    }
    inHidden = false;
    const cls   = l.type === 'add' ? 'diff-add' : l.type === 'remove' ? 'diff-remove' : 'diff-equal';
    const noOld = l.lineOld !== undefined ? l.lineOld : '';
    const noNew = l.lineNew !== undefined ? l.lineNew : '';
    const body  = l.inlineHtml !== undefined ? l.inlineHtml : esc(l.content);
    html += `<div class="diff-line ${cls}"><span class="diff-line-no">${noOld}</span><span class="diff-line-no">${noNew}</span><span class="diff-line-content">${body}</span></div>`;
  }
  html += '</div>';
  return html;
}

window._resultsName = '__RESULTS_NAME__';
init();
</script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    results_dir: Path = None

    def log_message(self, fmt, *args):
        pass  # silence access logs

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            html = HTML.replace("__RESULTS_NAME__", self.results_dir.name)
            self.wfile.write(html.encode())

        elif path == "/api/entries":
            self._json(find_entries(self.results_dir))

        elif path == "/api/files":
            problem = qs.get("problem", [""])[0]
            pair = qs.get("pair", [""])[0]
            artifact = qs.get("artifact", [""])[0]
            fa = qs.get("fa", [""])[0]
            fb = qs.get("fb", [""])[0]

            res_a = self.results_dir / problem / pair / artifact / "A" / "Formulation.lean"
            res_b = self.results_dir / problem / pair / artifact / "B" / "Formulation.lean"
            gt_a = REPO_ROOT / "dataset" / "problems" / problem / "formulations" / fa / "Formulation.lean"
            gt_b = REPO_ROOT / "dataset" / "problems" / problem / "formulations" / fb / "Formulation.lean"

            self._json({
                "gt_a": read_file(gt_a),
                "res_a": read_file(res_a),
                "gt_b": read_file(gt_b),
                "res_b": read_file(res_b),
                "path_gt_a": str(gt_a.relative_to(REPO_ROOT)),
                "path_res_a": str(res_a.relative_to(REPO_ROOT)),
                "path_gt_b": str(gt_b.relative_to(REPO_ROOT)),
                "path_res_b": str(res_b.relative_to(REPO_ROOT)),
            })

        else:
            self.send_response(404)
            self.end_headers()

    def _json(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-r", "--run-id", required=True, help="Run ID under results/")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    results_dir = (REPO_ROOT / "results" / args.run_id).resolve()
    if not results_dir.is_dir():
        print(f"Error: {results_dir} is not a directory")
        return

    Handler.results_dir = results_dir

    print(f"Serving {results_dir.name} at http://localhost:{args.port}")
    HTTPServer(("", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
