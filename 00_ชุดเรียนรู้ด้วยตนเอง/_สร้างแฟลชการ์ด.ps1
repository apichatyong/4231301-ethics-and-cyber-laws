# ============================================================
#  สร้างไฟล์ แฟลชการ์ด.html จากไฟล์ .md ทุกหัวข้อ
#  วิธีใช้: คลิกขวาที่ไฟล์นี้ > Run with PowerShell
#          หรือรันในเทอร์มินัล:  .\_สร้างแฟลชการ์ด.ps1
#  เมื่อแก้เนื้อหาในไฟล์ 02_แฟลชการ์ด*.md แล้ว ให้รันสคริปต์นี้อีกครั้ง
# ============================================================

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# รายการชุดแฟลชการ์ด (ชื่อหัวข้อ -> ไฟล์)
$decksDef = @(
    @{ name = 'PDPA';              file = '1_PDPA\02_แฟลชการ์ด_PDPA.md' }
    @{ name = 'พ.ร.บ.คอม/ไซเบอร์'; file = '2_พรบคอม-ไซเบอร์\02_แฟลชการ์ด_พรบคอม-ไซเบอร์.md' }
    @{ name = 'ทรัพย์สินทางปัญญา';  file = '3_ทรัพย์สินทางปัญญา\02_แฟลชการ์ด_IP.md' }
    @{ name = 'AI Law & Ethics';   file = '4_AI\02_แฟลชการ์ด_AI.md' }
    @{ name = 'ธุรกรรมอิเล็กทรอนิกส์'; file = '5_ธุรกรรมอิเล็กทรอนิกส์\02_แฟลชการ์ด+ข้อสอบ_ธุรกรรมอิเล็กทรอนิกส์.md' }
)

function Parse-Flashcards($path) {
    $lines = Get-Content -LiteralPath $path -Encoding UTF8
    $cards = New-Object System.Collections.ArrayList
    $section = ''
    $inTable = $false
    foreach ($raw in $lines) {
        $line = $raw.TrimEnd()
        # เก็บหัวข้อย่อย (## หรือ ###) เพื่อใช้เป็น tag
        if ($line -match '^#{2,3}\s+(.+)$') {
            $h = $Matches[1].Trim()
            # ข้ามหัวข้อที่เป็นส่วนข้อสอบ
            if ($h -notmatch 'ข้อสอบ|เฉลย|วิธีใช้') { $section = $h } else { $section = '' }
            $inTable = $false
            continue
        }
        if ($line -notmatch '^\s*\|') { $inTable = $false; continue }

        # เป็นแถวตาราง
        $cols = $line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }

        # แถว header ต้องมีคำว่า คำถาม + คำตอบ
        if (($cols -join '|') -match 'คำถาม' -and ($cols -join '|') -match 'คำตอบ') {
            $inTable = $true
            continue
        }
        # แถวเส้นคั่น |---|---|
        if ($line -match '^\s*\|[\s:|-]+\|?\s*$') { continue }

        if (-not $inTable) { continue }
        if ($cols.Count -lt 3) { continue }

        $q = $cols[1]
        $a = ($cols[2..($cols.Count-1)] -join ' | ').Trim()
        if ($q -eq '' -or $a -eq '') { continue }

        [void]$cards.Add([ordered]@{ q = $q; a = $a; tag = $section })
    }
    return $cards
}

$decks = New-Object System.Collections.ArrayList
foreach ($d in $decksDef) {
    $p = Join-Path $root $d.file
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Warning "ไม่พบไฟล์: $($d.file)  (ข้าม)"
        continue
    }
    $cards = Parse-Flashcards $p
    Write-Host ("  {0,-28} : {1} ใบ" -f $d.name, $cards.Count)
    [void]$decks.Add([ordered]@{ name = $d.name; cards = $cards })
}

$json = $decks | ConvertTo-Json -Depth 6 -Compress

# ---------- เทมเพลต HTML ----------
$html = @'
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>แฟลชการ์ด – จริยธรรมและกฎหมายไซเบอร์</title>
<style>
  :root{
    --bg:#0f172a; --panel:#1e293b; --card:#f8fafc; --card2:#fef9c3;
    --txt:#e2e8f0; --accent:#38bdf8; --good:#22c55e; --bad:#f87171; --muted:#94a3b8;
  }
  *{box-sizing:border-box}
  body{margin:0;font-family:"Sarabun","Segoe UI",Tahoma,sans-serif;background:var(--bg);color:var(--txt);
       min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:16px}
  h1{font-size:20px;margin:6px 0 2px;text-align:center}
  .sub{color:var(--muted);font-size:13px;margin-bottom:12px;text-align:center}
  .decks{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;max-width:820px;margin-bottom:14px}
  .deck-btn{background:var(--panel);color:var(--txt);border:1px solid #334155;border-radius:999px;
            padding:8px 14px;font-size:14px;cursor:pointer;transition:.15s;font-family:inherit}
  .deck-btn:hover{border-color:var(--accent)}
  .deck-btn.active{background:var(--accent);color:#03263a;border-color:var(--accent);font-weight:700}
  .deck-btn small{opacity:.7;margin-left:4px}
  .bar{display:flex;gap:10px;align-items:center;justify-content:center;flex-wrap:wrap;margin-bottom:10px;
       font-size:13px;color:var(--muted)}
  .toggle{display:flex;align-items:center;gap:6px;cursor:pointer;user-select:none}
  .progress{width:min(560px,92vw);height:8px;background:var(--panel);border-radius:99px;overflow:hidden;margin-bottom:14px}
  .progress > div{height:100%;background:var(--good);width:0;transition:.3s}
  .card{width:min(560px,92vw);min-height:300px;background:var(--card);color:#0f172a;border-radius:18px;
        padding:28px 26px;display:flex;flex-direction:column;justify-content:center;cursor:pointer;
        box-shadow:0 18px 40px rgba(0,0,0,.45);position:relative;transition:.15s;user-select:none}
  .card.flipped{background:var(--card2)}
  .card .side-label{position:absolute;top:14px;left:18px;font-size:12px;font-weight:700;letter-spacing:.5px;
        color:#64748b;text-transform:uppercase}
  .card .tag{position:absolute;top:12px;right:16px;font-size:11px;color:#64748b;max-width:55%;text-align:right}
  .card .content{font-size:21px;line-height:1.55;text-align:center;margin-top:8px}
  .card .content strong{color:#b91c1c}
  .card.flipped .content strong{color:#a16207}
  .hint{color:var(--muted);font-size:12px;text-align:center;margin-top:8px}
  .known-badge{position:absolute;bottom:12px;right:16px;font-size:12px;color:var(--good);font-weight:700;display:none}
  .card.is-known .known-badge{display:block}
  .controls{display:flex;gap:10px;margin-top:18px;flex-wrap:wrap;justify-content:center}
  button.act{border:none;border-radius:12px;padding:12px 18px;font-size:15px;cursor:pointer;font-family:inherit;
        font-weight:600;transition:.15s;color:#03263a}
  .nav{background:#475569;color:#fff}
  .bad{background:var(--bad);color:#3a0a0a}
  .good{background:var(--good)}
  button.act:hover{filter:brightness(1.08)}
  .counter{font-size:14px;color:var(--txt);margin-top:14px}
  .empty{color:var(--muted);margin-top:40px;text-align:center}
  a.reset{color:var(--muted);font-size:12px;margin-top:18px;cursor:pointer;text-decoration:underline}
  kbd{background:#334155;border-radius:5px;padding:1px 6px;font-size:11px}
</style>
</head>
<body>
  <a href="หน้าแรก.html" style="position:fixed;top:12px;left:14px;color:#94a3b8;font-size:13px;text-decoration:none;background:#1e293b;border:1px solid #334155;padding:6px 12px;border-radius:999px;z-index:99">🏠 หน้าแรก</a>
  <h1>🔑 แฟลชการ์ด — จริยธรรมและกฎหมายไซเบอร์</h1>
  <div class="sub">คลิกการ์ดเพื่อพลิกดูคำตอบ · <kbd>Space</kbd> พลิก · <kbd>←</kbd><kbd>→</kbd> เปลี่ยนใบ · <kbd>1</kbd> ยังไม่รู้ · <kbd>2</kbd> รู้แล้ว</div>

  <div class="decks" id="decks"></div>

  <div class="bar">
    <label class="toggle"><input type="checkbox" id="shuffle"> สลับลำดับ</label>
    <label class="toggle"><input type="checkbox" id="onlyUnknown"> ทบทวนเฉพาะที่ยังไม่รู้</label>
    <span id="stat"></span>
  </div>

  <div class="progress"><div id="pbar"></div></div>

  <div id="stage"></div>
  <div class="counter" id="counter"></div>
  <a class="reset" id="reset">ล้างสถานะ "รู้แล้ว" ของชุดนี้</a>

<script>
const DECKS = /*DECKS_JSON*/;

const $ = s => document.querySelector(s);
let deckIdx = 0;
let order = [];      // ลำดับการ์ดที่กำลังแสดง (index ใน deck.cards)
let pos = 0;
let flipped = false;

function deck(){ return DECKS[deckIdx]; }
function storeKey(){ return 'fc_known_' + deckIdx; }
function knownSet(){
  try { return new Set(JSON.parse(localStorage.getItem(storeKey()) || '[]')); }
  catch(e){ return new Set(); }
}
function saveKnown(set){ localStorage.setItem(storeKey(), JSON.stringify([...set])); }

function md(t){
  // escape HTML แล้วแปลง **bold** + ขึ้นบรรทัด
  const e = t.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  return e.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/\n/g,'<br>');
}

function buildOrder(){
  const d = deck();
  const known = knownSet();
  let idxs = d.cards.map((_,i)=>i);
  if ($('#onlyUnknown').checked) idxs = idxs.filter(i => !known.has(i));
  if ($('#shuffle').checked){
    for (let i=idxs.length-1;i>0;i--){ const j=Math.floor(Math.random()*(i+1)); [idxs[i],idxs[j]]=[idxs[j],idxs[i]]; }
  }
  order = idxs; pos = 0; flipped = false;
}

function renderDecks(){
  $('#decks').innerHTML = '';
  DECKS.forEach((d,i)=>{
    const b = document.createElement('button');
    b.className = 'deck-btn' + (i===deckIdx?' active':'');
    b.innerHTML = d.name + ' <small>('+d.cards.length+')</small>';
    b.onclick = ()=>{ deckIdx=i; buildOrder(); renderDecks(); render(); };
    $('#decks').appendChild(b);
  });
}

function render(){
  const d = deck();
  const known = knownSet();
  // progress
  const total = d.cards.length;
  const knownCount = [...known].filter(i=>i<total).length;
  $('#pbar').style.width = total ? (knownCount/total*100)+'%' : '0';
  $('#stat').textContent = `รู้แล้ว ${knownCount}/${total} ใบ`;

  if (order.length === 0){
    $('#stage').innerHTML = '<div class="empty">🎉 ไม่มีการ์ดให้แสดง<br>(อาจเพราะติ๊ก "ทบทวนเฉพาะที่ยังไม่รู้" แล้วรู้หมดแล้ว)</div>';
    $('#counter').textContent = '';
    return;
  }
  if (pos >= order.length) pos = order.length-1;
  const cardIdx = order[pos];
  const c = d.cards[cardIdx];
  const isKnown = known.has(cardIdx);

  const stage = document.createElement('div');
  stage.innerHTML = `
    <div class="card ${flipped?'flipped':''} ${isKnown?'is-known':''}" id="card">
      <div class="side-label">${flipped?'คำตอบ':'คำถาม'}</div>
      ${c.tag?`<div class="tag">${md(c.tag)}</div>`:''}
      <div class="content">${md(flipped?c.a:c.q)}</div>
      <div class="hint">${flipped?'':'แตะเพื่อดูคำตอบ'}</div>
      <div class="known-badge">✓ รู้แล้ว</div>
    </div>
    <div class="controls">
      <button class="act nav" id="prev">← ก่อนหน้า</button>
      <button class="act bad" id="dunno">✗ ยังไม่รู้</button>
      <button class="act good" id="know">✓ รู้แล้ว</button>
      <button class="act nav" id="next">ถัดไป →</button>
    </div>`;
  $('#stage').innerHTML = '';
  $('#stage').appendChild(stage);
  $('#counter').textContent = `ใบที่ ${pos+1} / ${order.length}`;

  $('#card').onclick = ()=>{ flipped=!flipped; render(); };
  $('#prev').onclick = (e)=>{ e.stopPropagation(); prev(); };
  $('#next').onclick = (e)=>{ e.stopPropagation(); next(); };
  $('#know').onclick = (e)=>{ e.stopPropagation(); mark(true); };
  $('#dunno').onclick = (e)=>{ e.stopPropagation(); mark(false); };
}

function next(){ if(pos<order.length-1){pos++;flipped=false;render();} }
function prev(){ if(pos>0){pos--;flipped=false;render();} }
function mark(isKnown){
  const cardIdx = order[pos];
  const set = knownSet();
  if (isKnown) set.add(cardIdx); else set.delete(cardIdx);
  saveKnown(set);
  if (pos<order.length-1){ next(); } else { render(); }
}

document.addEventListener('keydown', e=>{
  if (e.key===' '){ e.preventDefault(); flipped=!flipped; render(); }
  else if (e.key==='ArrowRight') next();
  else if (e.key==='ArrowLeft') prev();
  else if (e.key==='1') mark(false);
  else if (e.key==='2') mark(true);
});
$('#shuffle').onchange = ()=>{ buildOrder(); render(); };
$('#onlyUnknown').onchange = ()=>{ buildOrder(); render(); };
$('#reset').onclick = ()=>{ if(confirm('ล้างสถานะ "รู้แล้ว" ของชุด '+deck().name+' ?')){ localStorage.removeItem(storeKey()); buildOrder(); render(); } };

renderDecks();
buildOrder();
render();
</script>
</body>
</html>
'@

$html = $html.Replace('/*DECKS_JSON*/', $json)

$out = Join-Path $root 'แฟลชการ์ด.html'
# เขียนแบบ UTF-8 (ไม่มี BOM) ให้เบราว์เซอร์อ่านภาษาไทยถูก
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $html, $utf8)

Write-Host ""
Write-Host "สร้างไฟล์เรียบร้อย -> $out" -ForegroundColor Green
Write-Host "ดับเบิลคลิกไฟล์ แฟลชการ์ด.html เพื่อเปิดอ่านได้เลย"
