# -*- coding: utf-8 -*-
"""Generate SNAPSHOT.md and snapshot.html from register.py. Run: python3 build.py"""
import html, json, os, sys, datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import register as R

HERE = os.path.dirname(os.path.abspath(__file__))
AS_AT = "5 September 2026"

STATE = {
 "done_claude": ("Fixed in CJS code", "done"),
 "done_dev":    ("Closed by developer", "done"),
 "config":      ("CJS configuration", "cfg"),
 "backend":     ("Backend / record model", "be"),
 "portal":      ("Portal / framework", "pt"),
 "check":       ("Needs a look", "chk"),
}
CLOSED = ("done_claude", "done_dev")

by_j = {}
for t, seq, j, text, st, act in R.OBS:
    by_j.setdefault(j, []).append((t, seq, text, st, act))

def counts(rows):
    c = {k: 0 for k in STATE}
    for r in rows:
        c[r[3]] += 1
    return c

tot = counts([(0,0,0,o[4],0) for o in R.OBS])
n_obs = len(R.OBS)
n_closed = tot["done_claude"] + tot["done_dev"]
n_open = n_obs - n_closed

# ---------------------------------------------------------------- markdown
md = []
md.append(f"# CJS journey snapshot - {AS_AT}\n")
md.append("Built from the five Jira exports (Issues + Comments sheets). "
          "Regenerate with `python3 doc/tickets/build.py` after editing `register.py`.\n")
md.append(f"**{len(R.JOURNEYS)} journeys - {len(set(o[0] for o in R.OBS))} tickets - "
          f"{n_obs} observations - {n_closed} closed - {n_open} open**\n")
md.append("| Bucket | Count | Who closes it |")
md.append("| --- | ---: | --- |")
md.append(f"| Fixed in CJS code | {tot['done_claude']} | in git - abapGit Pull + activate |")
md.append(f"| Closed by developer | {tot['done_dev']} | already done |")
md.append(f"| CJS configuration | {tot['config']} | journey developer, in the Studio |")
md.append(f"| Backend / record model | {tot['backend']} | backend team |")
md.append(f"| Portal / framework | {tot['portal']} | portal team |")
md.append(f"| Needs a look | {tot['check']} | one run or one screenshot |")
md.append("")
md.append("## Waiting on an abapGit Pull\n")
md.append("A code fix is not live until the object is pulled AND activated. In the pull "
          "dialog every *Overwrite local object* row arrives **unticked**.\n")
md.append("| Object | What changed | Ticket |")
md.append("| --- | --- | --- |")
for o, w, t in R.PENDING_ACTIVATION:
    md.append(f"| `{o}` | {w} | {t} |")
md.append("")
for code, name, dept, tk, jst, who, note in R.JOURNEYS:
    rows = by_j.get(code, [])
    c = counts([(0,0,0,r[3],0) for r in rows])
    cl = c["done_claude"] + c["done_dev"]
    md.append(f"## {code} - {name}\n")
    md.append(f"{dept} · {tk} · {jst} · {who} · **{len(rows)} observations, "
              f"{cl} closed, {len(rows)-cl} open**\n")
    md.append(note + "\n")
    md.append("| # | Observation | Status | What closes it |")
    md.append("| ---: | --- | --- | --- |")
    for t, seq, text, st, act in rows:
        md.append(f"| {seq} | {text} | {STATE[st][0]} | {act} |")
    md.append("")
open(os.path.join(HERE, "SNAPSHOT.md"), "w").write("\n".join(md) + "\n")

# ---------------------------------------------------------------- html
e = html.escape
def chip(st):
    lab, cls = STATE[st]
    return f'<span class="chip {cls}">{lab}</span>'

parts = []
A = parts.append
A('<title>CJS Journey Board</title>')
A('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
  'family=Archivo:wght@500;600;700&family=IBM+Plex+Mono:wght@400;500&'
  'family=IBM+Plex+Sans:wght@400;500;600&display=swap">')
A("<style>%CSS%</style>")

A('<header class="top">')
A('<div class="wrap">')
A('<p class="eyebrow">RAK Customer Journey Studio · SIT round</p>')
A('<h1>Journey board</h1>')
A(f'<p class="lede">Every observation the testers raised across {len(set(o[0] for o in R.OBS))} '
  f'Jira tickets, said plainly, with who closes it and how. As at {AS_AT}.</p>')
A('<dl class="figs">')
for lab, val in (("Journeys", len(R.JOURNEYS)),
                 ("Tickets", len(set(o[0] for o in R.OBS))),
                 ("Observations", n_obs),
                 ("Closed", n_closed),
                 ("Open", n_open)):
    A(f'<div><dt>{lab}</dt><dd>{val}</dd></div>')
A('</dl>')
A('<div class="bar" role="img" aria-label="Where the work sits">')
for k in ("done_claude","done_dev","config","backend","portal","check"):
    pct = tot[k] * 100.0 / n_obs
    A(f'<span class="seg {STATE[k][1]}" style="width:{pct:.2f}%" title="{STATE[k][0]}: {tot[k]}"></span>')
A('</div>')
A('<ul class="legend">')
for k in ("done_claude","done_dev","config","backend","portal","check"):
    A(f'<li><i class="sw {STATE[k][1]}"></i>{STATE[k][0]} <b>{tot[k]}</b></li>')
A('</ul>')
A('</div></header>')

A('<div class="wrap">')
A('<section class="callout">')
A('<h2>Before any code fix counts</h2>')
A('<p>The fixes below are in git on <code>main</code>. They do nothing in SAP until each object '
  'is pulled <em>and</em> activated. In the abapGit pull dialog every <em>Overwrite local object</em> '
  'row arrives unticked, and the ticks reset each time the dialog opens - so an existing class is '
  'skipped unless you tick it by hand. Activate <code>ZCL_RAK_JOURNEY_LOGIC</code> and '
  '<code>ZCL_RAK_JOURNEY_RENDER</code> first; they break widest.</p>')
A('<table class="pend"><thead><tr><th>Object</th><th>What changed</th><th>Ticket</th></tr></thead><tbody>')
for o, w, t in R.PENDING_ACTIVATION:
    A(f'<tr><td><code>{e(o)}</code></td><td>{e(w)}</td><td class="num">{e(t)}</td></tr>')
A('</tbody></table>')
A('</section>')

A('<div class="filters" id="filters">')
A('<input type="search" id="q" placeholder="Search observations, journeys, field names" aria-label="Search">')
A('<div class="chips" id="stchips">')
for k in ("done_claude","done_dev","config","backend","portal","check"):
    A(f'<button class="fchip {STATE[k][1]}" data-st="{k}" aria-pressed="false">{STATE[k][0]}'
      f'<b>{tot[k]}</b></button>')
A('</div>')
A('<div class="chips">')
for d in ("DOK","EPDA"):
    A(f'<button class="fchip dept" data-dept="{d}" aria-pressed="false">{d}</button>')
A('<button class="fchip clear" id="clear">Clear</button>')
A('</div>')
A('</div>')
A('<p class="shown" id="shown"></p>')

for code, name, dept, tk, jst, who, note in R.JOURNEYS:
    rows = by_j.get(code, [])
    c = counts([(0,0,0,r[3],0) for r in rows])
    cl = c["done_claude"] + c["done_dev"]
    A(f'<section class="jny" data-dept="{dept}" data-code="{code}">')
    A('<div class="jhead">')
    A(f'<h2><span class="jcode">{code}</span> {e(name)}</h2>')
    A(f'<p class="meta"><span class="dept {dept}">{dept}</span>'
      f'<span>{tk}</span><span>{jst}</span><span>{e(who)}</span></p>')
    A('</div>')
    A('<div class="prog"><div class="pbar">')
    for k in ("done_claude","done_dev","config","backend","portal","check"):
        if c[k]:
            A(f'<span class="seg {STATE[k][1]}" style="width:{c[k]*100.0/len(rows):.2f}%"></span>')
    A('</div>')
    A(f'<p class="pnum"><b>{cl}</b> of {len(rows)} closed</p></div>')
    A(f'<p class="note">{e(note)}</p>')
    A('<table class="obs"><thead><tr><th class="n">#</th><th>Observation</th>'
      '<th>Status</th><th>What closes it</th></tr></thead><tbody>')
    for t, seq, text, st, act in rows:
        hay = e((text + " " + act + " " + code + " " + name + " " + t).lower())
        A(f'<tr data-st="{st}" data-hay="{hay}">'
          f'<td class="n">{seq}</td><td class="what">{e(text)}</td>'
          f'<td>{chip(st)}</td><td class="how">{e(act)}</td></tr>')
    A('</tbody></table>')
    A('</section>')

A('<footer><p>Source: Jira exports of 5 September 2026, Issues and Comments sheets, five assignees. '
  'The register lives in the repository at <code>doc/tickets/register.py</code>; this page is '
  'generated from it by <code>doc/tickets/build.py</code>, so the next round is an edit and a re-run.</p>'
  '<p>Nothing on this page has been compiled or activated - there is no SAP connection from where it '
  'was written. Code marked fixed is fixed in git.</p></footer>')
A('</div>')
A("<script>%JS%</script>")

CSS = r"""
:root{
  --ground:#EEF2F2; --surface:#FFFFFF; --surface2:#F6F9F9; --raise:#FBFDFD;
  --ink:#0F1A1B; --ink2:#4B5C5E; --ink3:#6E8082; --rule:#D5DEDE; --rule2:#E6ECEC;
  --accent:#0B6E68;
  --done:#1C6B43; --cfg:#9E5A08; --be:#5B4B8A; --pt:#4A5A72; --chk:#9C3A52;
  --doneb:#E4F0E9; --cfgb:#F7EBDC; --beb:#EBE7F4; --ptb:#E7EBF1; --chkb:#F7E5E9;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --ground:#0D1314; --surface:#141C1D; --surface2:#182122; --raise:#1C2627;
    --ink:#E3ECEB; --ink2:#A2B3B3; --ink3:#7E9091; --rule:#263234; --rule2:#1F2A2B;
    --accent:#4FBDB2;
    --done:#66C08D; --cfg:#E0A54E; --be:#A99AE0; --pt:#9DAFC9; --chk:#E88CA0;
    --doneb:#162A20; --cfgb:#2C2113; --beb:#211C33; --ptb:#1A222C; --chkb:#2E1A20;
  }
}
:root[data-theme="dark"]{
  --ground:#0D1314; --surface:#141C1D; --surface2:#182122; --raise:#1C2627;
  --ink:#E3ECEB; --ink2:#A2B3B3; --ink3:#7E9091; --rule:#263234; --rule2:#1F2A2B;
  --accent:#4FBDB2;
  --done:#66C08D; --cfg:#E0A54E; --be:#A99AE0; --pt:#9DAFC9; --chk:#E88CA0;
  --doneb:#162A20; --cfgb:#2C2113; --beb:#211C33; --ptb:#1A222C; --chkb:#2E1A20;
}
*{box-sizing:border-box}
body{background:var(--ground);color:var(--ink);
  font-family:"IBM Plex Sans",-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  font-size:15px;line-height:1.55;-webkit-font-smoothing:antialiased}
.wrap{max-width:1120px;margin:0 auto;padding:0 24px}
code{font-family:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,monospace;
  font-size:.88em;color:var(--ink);background:var(--surface2);
  padding:1px 5px;border-radius:3px;border:1px solid var(--rule2)}
h1,h2,h3{font-family:Archivo,"IBM Plex Sans",sans-serif;text-wrap:balance;margin:0}
.top{background:var(--surface);border-bottom:1px solid var(--rule);padding:44px 0 28px}
.eyebrow{font-size:11.5px;letter-spacing:.14em;text-transform:uppercase;
  color:var(--accent);font-weight:600;margin:0 0 10px}
h1{font-size:clamp(30px,4.4vw,46px);font-weight:700;letter-spacing:-.02em;line-height:1.04}
.lede{max-width:62ch;color:var(--ink2);margin:12px 0 0;font-size:16px}
.figs{display:flex;flex-wrap:wrap;gap:36px;margin:28px 0 0}
.figs div{display:flex;flex-direction:column-reverse}
.figs dt{font-size:11.5px;letter-spacing:.09em;text-transform:uppercase;color:var(--ink3);margin:2px 0 0}
.figs dd{margin:0;font-family:Archivo,sans-serif;font-weight:600;font-size:28px;
  font-variant-numeric:tabular-nums;line-height:1}
.bar{display:flex;height:10px;border-radius:5px;overflow:hidden;margin:26px 0 12px;
  background:var(--surface2)}
.seg{display:block;height:100%}
.seg.done{background:var(--done)} .seg.cfg{background:var(--cfg)}
.seg.be{background:var(--be)} .seg.pt{background:var(--pt)} .seg.chk{background:var(--chk)}
.legend{list-style:none;display:flex;flex-wrap:wrap;gap:6px 22px;margin:0;padding:0;
  font-size:13px;color:var(--ink2)}
.legend li{display:flex;align-items:center;gap:7px}
.legend b{font-variant-numeric:tabular-nums;color:var(--ink)}
.sw{width:9px;height:9px;border-radius:2px;display:inline-block}
.sw.done{background:var(--done)} .sw.cfg{background:var(--cfg)}
.sw.be{background:var(--be)} .sw.pt{background:var(--pt)} .sw.chk{background:var(--chk)}
.callout{margin:36px 0 0;padding:22px 24px;background:var(--surface);
  border:1px solid var(--rule);border-left:3px solid var(--accent);border-radius:2px}
.callout h2{font-size:19px;font-weight:600;letter-spacing:-.01em}
.callout p{color:var(--ink2);max-width:74ch;margin:8px 0 16px}
table{border-collapse:collapse;width:100%}
.pend{font-size:13.5px}
.pend th{text-align:left;font-weight:600;font-size:11px;letter-spacing:.09em;
  text-transform:uppercase;color:var(--ink3);padding:0 12px 6px 0;border-bottom:1px solid var(--rule)}
.pend td{padding:7px 12px 7px 0;border-bottom:1px solid var(--rule2);vertical-align:top;color:var(--ink2)}
.pend td.num{font-family:"IBM Plex Mono",monospace;font-size:12px;white-space:nowrap;color:var(--ink3)}
.filters{position:sticky;top:0;z-index:5;background:var(--ground);
  padding:18px 0 12px;margin:36px 0 0;border-bottom:1px solid var(--rule);
  display:flex;flex-wrap:wrap;gap:10px 16px;align-items:center}
#q{flex:1 1 280px;min-width:220px;padding:9px 12px;border:1px solid var(--rule);
  border-radius:3px;background:var(--surface);color:var(--ink);font:inherit;font-size:14px}
#q:focus-visible,.fchip:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.chips{display:flex;flex-wrap:wrap;gap:7px}
.fchip{font:inherit;font-size:12.5px;padding:6px 11px;border-radius:99px;cursor:pointer;
  background:var(--surface);color:var(--ink2);border:1px solid var(--rule);
  display:inline-flex;align-items:center;gap:7px}
.fchip b{font-variant-numeric:tabular-nums;color:var(--ink3);font-weight:500}
.fchip[aria-pressed="true"]{background:var(--ink);color:var(--ground);border-color:var(--ink)}
.fchip[aria-pressed="true"] b{color:var(--ground);opacity:.7}
.shown{font-size:12.5px;color:var(--ink3);margin:12px 0 0;height:1em}
.jny{margin:34px 0 0;background:var(--surface);border:1px solid var(--rule);border-radius:2px;
  padding:22px 24px 6px}
.jhead{display:flex;flex-wrap:wrap;gap:6px 18px;align-items:baseline;justify-content:space-between}
.jny h2{font-size:21px;font-weight:600;letter-spacing:-.01em}
.jcode{font-family:"IBM Plex Mono",monospace;font-size:16px;font-weight:500;
  color:var(--accent);margin-right:8px}
.meta{display:flex;gap:14px;margin:0;font-size:12.5px;color:var(--ink3);
  font-family:"IBM Plex Mono",monospace}
.dept{font-weight:500;color:var(--ink2)}
.prog{display:flex;align-items:center;gap:14px;margin:16px 0 0}
.pbar{display:flex;height:6px;flex:1;border-radius:3px;overflow:hidden;background:var(--surface2)}
.pnum{margin:0;font-size:12.5px;color:var(--ink3);white-space:nowrap;font-variant-numeric:tabular-nums}
.pnum b{color:var(--ink)}
.note{color:var(--ink2);max-width:78ch;margin:14px 0 4px;font-size:14.5px}
.obs{font-size:14px;margin:10px 0 0}
.obs th{text-align:left;font-weight:600;font-size:11px;letter-spacing:.09em;text-transform:uppercase;
  color:var(--ink3);padding:10px 14px 7px 0;border-bottom:1px solid var(--rule)}
.obs td{padding:11px 14px 11px 0;border-bottom:1px solid var(--rule2);vertical-align:top}
.obs tr:last-child td{border-bottom:0}
.obs .n{width:26px;color:var(--ink3);font-variant-numeric:tabular-nums;font-size:12.5px;padding-top:12px}
.obs .what{width:34%;color:var(--ink)}
.obs .how{color:var(--ink2);font-size:13.5px}
.obs td:nth-child(3){width:172px}
.chip{display:inline-block;font-size:11.5px;font-weight:500;padding:3px 9px;border-radius:99px;
  white-space:nowrap;line-height:1.4}
.chip.done{background:var(--doneb);color:var(--done)}
.chip.cfg{background:var(--cfgb);color:var(--cfg)}
.chip.be{background:var(--beb);color:var(--be)}
.chip.pt{background:var(--ptb);color:var(--pt)}
.chip.chk{background:var(--chkb);color:var(--chk)}
.jny.hide,.obs tr.hide{display:none}
footer{margin:48px 0 60px;padding:20px 0 0;border-top:1px solid var(--rule);
  font-size:13px;color:var(--ink3);max-width:80ch}
footer p{margin:0 0 8px}
@media (max-width:720px){
  .obs td:nth-child(3){width:auto}
  .obs .what{width:auto}
  .obs,.pend{display:block;overflow-x:auto}
  .figs{gap:24px}
}
@media (prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
"""

JS = r"""
(function(){
  var q=document.getElementById('q'), shown=document.getElementById('shown');
  var st=new Set(), dept=new Set();
  function chips(){return Array.prototype.slice.call(document.querySelectorAll('.fchip[data-st],.fchip[data-dept]'));}
  function apply(){
    var term=(q.value||'').trim().toLowerCase(), vis=0, tot=0;
    document.querySelectorAll('.jny').forEach(function(j){
      var any=false;
      if(dept.size && !dept.has(j.dataset.dept)){ j.classList.add('hide');
        j.querySelectorAll('tbody tr').forEach(function(r){tot++;}); return; }
      j.querySelectorAll('tbody tr').forEach(function(r){
        tot++;
        var ok=(!st.size||st.has(r.dataset.st)) && (!term||r.dataset.hay.indexOf(term)>-1);
        r.classList.toggle('hide',!ok); if(ok){any=true;vis++;}
      });
      j.classList.toggle('hide',!any);
    });
    shown.textContent = (st.size||dept.size||term) ? ('Showing '+vis+' of '+tot+' observations') : '';
  }
  chips().forEach(function(b){
    b.addEventListener('click',function(){
      var on=b.getAttribute('aria-pressed')==='true';
      b.setAttribute('aria-pressed',on?'false':'true');
      var set=b.dataset.st?st:dept, key=b.dataset.st||b.dataset.dept;
      if(on){set.delete(key);}else{set.add(key);}
      apply();
    });
  });
  q.addEventListener('input',apply);
  document.getElementById('clear').addEventListener('click',function(){
    st.clear();dept.clear();q.value='';
    chips().forEach(function(b){b.setAttribute('aria-pressed','false');});
    apply();
  });
})();
"""

out = "\n".join(p for p in parts if p)
out = out.replace("%CSS%", CSS).replace("%JS%", JS)
open(os.path.join(HERE, "snapshot.html"), "w").write(out)
json.dump({"as_at": AS_AT,
           "journeys": [dict(zip(("code","name","dept","ticket","jira","assignee","note"), j)) for j in R.JOURNEYS],
           "observations": [dict(zip(("ticket","seq","journey","observation","state","action"), o)) for o in R.OBS],
           "pending_activation": [dict(zip(("object","change","ticket"), p)) for p in R.PENDING_ACTIVATION]},
          open(os.path.join(HERE, "register.json"), "w"), indent=1, ensure_ascii=False)
print("SNAPSHOT.md, snapshot.html, register.json written")
