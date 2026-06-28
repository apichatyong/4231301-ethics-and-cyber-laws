# ============================================================
#  สร้างไฟล์ แบบทดสอบ.html (ข้อสอบปรนัย) จากไฟล์ .md ทุกหัวข้อ
#  วิธีใช้: คลิกขวาที่ไฟล์นี้ > Run with PowerShell
#  เมื่อแก้เนื้อหาข้อสอบในไฟล์ .md แล้ว ให้รันสคริปต์นี้อีกครั้ง
# ============================================================

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$quizDef = @(
    @{ name = 'PDPA';                file = '1_PDPA\03_ข้อสอบปรนัย_PDPA.md' }
    @{ name = 'พ.ร.บ.คอม/ไซเบอร์';   file = '2_พรบคอม-ไซเบอร์\03_ข้อสอบปรนัย+อัตนัย_พรบคอม-ไซเบอร์.md' }
    @{ name = 'ทรัพย์สินทางปัญญา';    file = '3_ทรัพย์สินทางปัญญา\03_ข้อสอบปรนัย+อัตนัย_IP.md' }
    @{ name = 'AI Law & Ethics';     file = '4_AI\03_ข้อสอบปรนัย+อัตนัย_AI.md' }
    @{ name = 'ธุรกรรมอิเล็กทรอนิกส์'; file = '5_ธุรกรรมอิเล็กทรอนิกส์\02_แฟลชการ์ด+ข้อสอบ_ธุรกรรมอิเล็กทรอนิกส์.md' }
    @{ name = '★ ข้อสอบจำลอง 60 คะแนน'; file = '6_คลังเคส_ข้อสอบรวม\04_ข้อสอบจำลอง_60คะแนน.md'; answerFile = '6_คลังเคส_ข้อสอบรวม\05_เฉลยข้อสอบจำลอง.md' }
)

# แปลงตัวอักษรตัวเลือก -> index
$letterIndex = @{ 'ก'=0; 'ข'=1; 'ค'=2; 'ง'=3; 'จ'=4 }

function Parse-AnswerKey($lines) {
    # คืน hashtable: เลขข้อ(int) -> @{ letter; explain }
    $key = @{}
    # --- แบบตารางแนวตั้ง (มีคำอธิบาย): | 1 | **ค** | คำอธิบาย | ---
    foreach ($l in $lines) {
        if ($l -match '^\s*\|\s*(\d+)\s*\|\s*\**\s*([ก-จ])\s*\**\s*\|(.+)$') {
            $n = [int]$Matches[1]
            $expl = $Matches[3].Trim().TrimEnd('|').Trim()
            if ($expl -notmatch '^\**[ก-จ]\**$' -and $expl -ne '') {
                $key[$n] = @{ letter = $Matches[2]; explain = $expl }
            }
        }
    }
    # --- แบบคู่ เลข|ตอบ ในแถวเดียว (รองรับหลายคู่ เช่น | 1 | ข | 11 | ก | 21 | ข |) ---
    foreach ($l in $lines) {
        if ($l -notmatch '^\s*\|') { continue }
        if ($l -match '^\s*\|[\s:|-]+\|?\s*$') { continue }
        $cells = $l.Trim().Trim('|').Split('|') | ForEach-Object { ($_ -replace '\*','').Trim() }
        for ($k = 0; $k -lt $cells.Count - 1; $k++) {
            if ($cells[$k] -match '^\d+$' -and $cells[$k+1] -match '^[ก-จ]$') {
                $n = [int]$cells[$k]
                if (-not $key.ContainsKey($n)) { $key[$n] = @{ letter = $cells[$k+1]; explain = '' } }
            }
        }
    }
    # --- แบบตารางแนวนอน: แถวเลข แล้วแถวตัวอักษร ---
    for ($i = 0; $i -lt $lines.Count - 1; $i++) {
        $l = $lines[$i]
        if ($l -notmatch '^\s*\|') { continue }
        $headCells = $l.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        $allNum = ($headCells.Count -gt 0) -and -not ($headCells | Where-Object { $_ -notmatch '^\d+$' })
        if (-not $allNum) { continue }
        # หาแถวข้อมูลถัดไป (ข้ามแถวเส้นคั่น)
        $j = $i + 1
        while ($j -lt $lines.Count -and $lines[$j] -match '^\s*\|[\s:|-]+\|?\s*$') { $j++ }
        if ($j -ge $lines.Count -or $lines[$j] -notmatch '^\s*\|') { continue }
        $ansCells = $lines[$j].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() -replace '\*','' }
        $allLetter = ($ansCells.Count -gt 0) -and -not ($ansCells | Where-Object { $_ -notmatch '^[ก-จ]$' })
        if (-not $allLetter) { continue }
        $cnt = [Math]::Min($headCells.Count, $ansCells.Count)
        for ($k = 0; $k -lt $cnt; $k++) {
            $n = [int]$headCells[$k]
            if (-not $key.ContainsKey($n)) { $key[$n] = @{ letter = $ansCells[$k]; explain = '' } }
        }
    }
    return $key
}

# หาตำแหน่งตัวมาร์กตัวเลือก (X.) ที่ "ขึ้นต้น/มีช่องว่างนำหน้า" เท่านั้น
# เพื่อกันการจับ "ค." ในชื่อย่อเดือน (พ.ค./ม.ค.) หรือ "ก." ในชื่อคน (นาย ก.)
function Find-Marker($s, $letter, $start) {
    $i = $start
    while ($i -le $s.Length) {
        $idx = $s.IndexOf("$letter.", $i)
        if ($idx -lt 0) { return -1 }
        if ($idx -eq 0 -or [char]::IsWhiteSpace($s[$idx-1])) { return $idx }
        $i = $idx + 1
    }
    return -1
}

function Split-Options($text) {
    # แยกตัวเลือกแบบเรียงลำดับ ก -> ข -> ค -> ง (-> จ) หาทีละตัวต่อจากตัวก่อนหน้า
    $s = ($text -join "`n")
    $order = @('ก','ข','ค','ง','จ')
    $pos = @()
    $start = 0
    foreach ($mk in $order) {
        $idx = Find-Marker $s $mk $start
        if ($idx -lt 0) { break }
        $pos += @{ letter = $mk; idx = $idx }
        $start = $idx + 2
    }
    $opts = @()
    for ($p = 0; $p -lt $pos.Count; $p++) {
        $from = $pos[$p].idx + 2          # ข้าม "X."
        $to = if ($p + 1 -lt $pos.Count) { $pos[$p+1].idx } else { $s.Length }
        $opts += (($s.Substring($from, $to - $from)) -replace '\s+',' ').Trim()
    }
    return ,$opts
}

function Parse-Quiz($path, $answerPath) {
    $lines = Get-Content -LiteralPath $path -Encoding UTF8
    if ($answerPath) { $key = Parse-AnswerKey (Get-Content -LiteralPath $answerPath -Encoding UTF8) }
    else             { $key = Parse-AnswerKey $lines }

    $questions = New-Object System.Collections.ArrayList
    $stopParsing = $false
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        # หยุดเก็บโจทย์เมื่อถึง "หัวข้อเฉลย" จริง (ขึ้นต้นด้วยเฉลย ไม่นับหัวข้อที่มีคำว่าเฉลยปนอยู่)
        if ($line -match '^#{1,6}[^ก-ฮ]*เฉลย') { $stopParsing = $true }
        if ($stopParsing) { $i++; continue }

        if ($line -match '^\*\*(\d+)\.\*\*\s*(.*)$') {
            $num = [int]$Matches[1]
            $stem = $Matches[2].Trim()
            # เก็บบรรทัดตัวเลือก (จนเจอบรรทัดว่าง/โจทย์ถัดไป/หัวข้อ)
            $optLines = @()
            $j = $i + 1
            while ($j -lt $lines.Count) {
                $nx = $lines[$j]
                if ($nx.Trim() -eq '') { break }
                if ($nx -match '^\*\*\d+\.\*\*') { break }
                if ($nx -match '^#{1,6}\s') { break }
                if ($nx -match '^<details') { break }
                $optLines += $nx
                $j++
            }
            # หาแหล่งตัวเลือก: ถ้ามีบรรทัดถัดไป = แบบหลายบรรทัด; ถ้าไม่มี = แบบอินไลน์ (หลัง "—")
            $question = $stem
            if ($optLines.Count -ge 1) {
                $optSource = $optLines
            } else {
                $di = -1
                foreach ($dch in @([char]0x2014, [char]0x2013)) { $di = $stem.IndexOf($dch); if ($di -ge 0) { break } }
                if ($di -ge 0) {
                    $question = $stem.Substring(0, $di).Trim()
                    $optSource = @($stem.Substring($di + 1))
                } else {
                    $optSource = @($stem)   # ไม่มีตัวเลือกชัดเจน เดี๋ยวถูกคัดออก
                }
            }
            $opts = Split-Options $optSource
            # ต้องมีตัวเลือก >=2 และมีเฉลย จึงนับเป็นข้อปรนัย
            if ($opts.Count -ge 2 -and $key.ContainsKey($num)) {
                $letter = $key[$num].letter
                $correct = $letterIndex[$letter]
                if ($correct -ne $null -and $correct -lt $opts.Count) {
                    [void]$questions.Add([ordered]@{
                        q = $question
                        options = $opts
                        correct = $correct
                        explain = $key[$num].explain
                    })
                }
            }
            $i = $j
            continue
        }
        $i++
    }
    return $questions
}

$quizzes = New-Object System.Collections.ArrayList
foreach ($d in $quizDef) {
    $p = Join-Path $root $d.file
    if (-not (Test-Path -LiteralPath $p)) { Write-Warning "ไม่พบไฟล์: $($d.file)"; continue }
    $ap = if ($d.answerFile) { Join-Path $root $d.answerFile } else { $null }
    $qs = Parse-Quiz $p $ap
    Write-Host ("  {0,-28} : {1} ข้อ" -f $d.name, $qs.Count)
    [void]$quizzes.Add([ordered]@{ name = $d.name; questions = $qs })
}

$json = $quizzes | ConvertTo-Json -Depth 8 -Compress

$html = @'
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>แบบทดสอบ – จริยธรรมและกฎหมายไซเบอร์</title>
<style>
  :root{--bg:#0f172a;--panel:#1e293b;--txt:#e2e8f0;--accent:#38bdf8;--good:#22c55e;--bad:#f87171;--muted:#94a3b8;--line:#334155}
  *{box-sizing:border-box}
  body{margin:0;font-family:"Sarabun","Segoe UI",Tahoma,sans-serif;background:var(--bg);color:var(--txt);
       min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:18px}
  h1{font-size:20px;margin:4px 0 2px;text-align:center}
  .sub{color:var(--muted);font-size:13px;margin-bottom:16px;text-align:center}
  .wrap{width:min(640px,94vw)}
  .panel{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:20px}
  .row{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-bottom:14px}
  .row label{font-size:13px;color:var(--muted);min-width:96px}
  .chip{background:#0b1220;color:var(--txt);border:1px solid var(--line);border-radius:999px;padding:7px 13px;
        font-size:13px;cursor:pointer;font-family:inherit}
  .chip.active{background:var(--accent);color:#03263a;border-color:var(--accent);font-weight:700}
  select{background:#0b1220;color:var(--txt);border:1px solid var(--line);border-radius:8px;padding:7px 10px;font-family:inherit;font-size:14px}
  .start{background:var(--accent);color:#03263a;border:none;border-radius:12px;padding:13px;font-size:16px;font-weight:700;
        width:100%;cursor:pointer;font-family:inherit;margin-top:6px}
  .start:hover{filter:brightness(1.07)}
  .topbar{display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;font-size:14px;color:var(--muted)}
  .pbar{height:7px;background:#0b1220;border-radius:99px;overflow:hidden;flex:1;margin:0 12px}
  .pbar>div{height:100%;background:var(--accent);width:0;transition:.3s}
  .qnum{color:var(--accent);font-weight:700;font-size:13px;margin-bottom:6px}
  .qtext{font-size:18px;line-height:1.6;margin-bottom:16px}
  .qtext strong{color:#fca5a5}
  .opt{display:flex;gap:10px;align-items:flex-start;background:#0b1220;border:1.5px solid var(--line);border-radius:12px;
       padding:13px 15px;margin-bottom:10px;cursor:pointer;font-size:15px;line-height:1.5;transition:.12s}
  .opt:hover{border-color:var(--accent)}
  .opt .k{font-weight:700;color:var(--muted);min-width:18px}
  .opt.correct{border-color:var(--good);background:rgba(34,197,94,.13)}
  .opt.wrong{border-color:var(--bad);background:rgba(248,113,113,.13)}
  .opt.correct .k{color:var(--good)} .opt.wrong .k{color:var(--bad)}
  .opt.disabled{cursor:default}
  .explain{background:#0b1220;border-left:3px solid var(--accent);border-radius:8px;padding:11px 14px;margin:6px 0 14px;
           font-size:14px;line-height:1.6;color:#cbd5e1}
  .explain strong{color:var(--accent)}
  .next{background:var(--accent);color:#03263a;border:none;border-radius:10px;padding:11px 20px;font-size:15px;font-weight:700;
        cursor:pointer;font-family:inherit;float:right}
  .next:hover{filter:brightness(1.07)}
  .result{text-align:center}
  .score{font-size:46px;font-weight:800;margin:10px 0}
  .grade{font-size:16px;margin-bottom:18px}
  .review-item{text-align:left;background:#0b1220;border:1px solid var(--line);border-radius:10px;padding:12px 14px;margin-bottom:10px;font-size:14px;line-height:1.55}
  .review-item .q{margin-bottom:6px}
  .review-item .ans{color:var(--bad)} .review-item .cor{color:var(--good)}
  .clearfix::after{content:'';display:block;clear:both}
  .hidden{display:none}
</style>
</head>
<body>
  <a href="หน้าแรก.html" style="position:fixed;top:12px;left:14px;color:#94a3b8;font-size:13px;text-decoration:none;background:#1e293b;border:1px solid #334155;padding:6px 12px;border-radius:999px;z-index:99">🏠 หน้าแรก</a>
  <h1>📝 แบบทดสอบ — จริยธรรมและกฎหมายไซเบอร์</h1>
  <div class="sub">ทำข้อสอบปรนัยจากคลังข้อสอบ มีเฉลย+คำอธิบาย รู้ผลทันที</div>

  <div class="wrap">
    <!-- หน้าตั้งค่า -->
    <div class="panel" id="setup">
      <div class="row">
        <label>หัวข้อ</label>
        <div id="topicChips" style="display:flex;flex-wrap:wrap;gap:8px"></div>
      </div>
      <div class="row">
        <label>จำนวนข้อ</label>
        <div id="countChips" style="display:flex;flex-wrap:wrap;gap:8px"></div>
      </div>
      <div class="row">
        <label>โหมดเฉลย</label>
        <select id="mode">
          <option value="instant">เฉลยทันทีหลังตอบ (เหมาะกับการฝึก)</option>
          <option value="exam">เฉลยตอนจบ (โหมดสอบ)</option>
        </select>
      </div>
      <div class="row">
        <label></label>
        <label style="min-width:auto;color:var(--txt);cursor:pointer"><input type="checkbox" id="shuffleOpt" checked> สลับลำดับตัวเลือก</label>
      </div>
      <button class="start" id="startBtn">เริ่มทำข้อสอบ ▶</button>
    </div>

    <!-- หน้าทำข้อสอบ -->
    <div class="panel hidden" id="quiz">
      <div class="topbar">
        <span id="qcount"></span>
        <div class="pbar"><div id="qprog"></div></div>
        <span id="qscore"></span>
      </div>
      <div class="qnum" id="qnum"></div>
      <div class="qtext" id="qtext"></div>
      <div id="opts"></div>
      <div class="explain hidden" id="explain"></div>
      <div class="clearfix"><button class="next hidden" id="nextBtn">ถัดไป →</button></div>
    </div>

    <!-- หน้าผลคะแนน -->
    <div class="panel hidden result" id="result">
      <div class="score" id="scoreNum"></div>
      <div class="grade" id="grade"></div>
      <div id="review" style="margin-top:14px"></div>
      <button class="start" id="againBtn" style="margin-top:16px">ทำใหม่อีกครั้ง ↻</button>
    </div>
  </div>

<script>
const QUIZZES = /*QUIZ_JSON*/;
const LETTERS = ['ก','ข','ค','ง','จ'];
const $ = s => document.querySelector(s);

let topicIdx = -1;      // -1 = รวมทุกหัวข้อ
let qCountSel = 'all';
let quiz = [];          // ชุดข้อสอบรอบนี้
let cur = 0, score = 0, answered = false;
let wrongs = [];

function md(t){
  const e = (t||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  return e.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>');
}
function shuffle(a){ a=a.slice(); for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];} return a; }
function pool(){
  if (topicIdx===-1) return QUIZZES.flatMap(t=>t.questions);
  return QUIZZES[topicIdx].questions;
}

function renderSetup(){
  const tc = $('#topicChips'); tc.innerHTML='';
  const mk=(label,idx)=>{const b=document.createElement('button');b.className='chip'+(idx===topicIdx?' active':'');
    b.textContent=label;b.onclick=()=>{topicIdx=idx;renderSetup();};tc.appendChild(b);};
  mk('รวมทุกหัวข้อ ('+QUIZZES.flatMap(t=>t.questions).length+')',-1);
  QUIZZES.forEach((t,i)=>mk(t.name+' ('+t.questions.length+')',i));

  const cc=$('#countChips'); cc.innerHTML='';
  const total=pool().length;
  const opts=[10,20,'all'].filter(n=>n==='all'||n<=total);
  if(opts.length===0||opts[0]==='all') opts.unshift = opts;
  [...new Set(opts)].forEach(n=>{
    const b=document.createElement('button');b.className='chip'+(n==qCountSel?' active':'');
    b.textContent=(n==='all'?('ทั้งหมด ('+total+')'):n+' ข้อ');
    b.onclick=()=>{qCountSel=n;renderSetup();};cc.appendChild(b);
  });
  if(![...new Set(opts)].some(n=>n==qCountSel)) qCountSel='all';
}

function start(){
  let qs = shuffle(pool());
  if (qCountSel!=='all') qs = qs.slice(0, qCountSel);
  quiz = qs.map(q=>{
    let idxs = q.options.map((_,i)=>i);
    if ($('#shuffleOpt').checked) idxs = shuffle(idxs);
    return { q:q.q, explain:q.explain,
             options: idxs.map(i=>q.options[i]),
             correct: idxs.indexOf(q.correct) };
  });
  cur=0; score=0; wrongs=[];
  $('#setup').classList.add('hidden'); $('#result').classList.add('hidden');
  $('#quiz').classList.remove('hidden');
  renderQ();
}

function renderQ(){
  answered=false;
  const q=quiz[cur];
  $('#qcount').textContent='ข้อ '+(cur+1)+' / '+quiz.length;
  $('#qscore').textContent='คะแนน '+score;
  $('#qprog').style.width=(cur/quiz.length*100)+'%';
  $('#qnum').textContent='คำถามที่ '+(cur+1);
  $('#qtext').innerHTML=md(q.q);
  $('#explain').classList.add('hidden');
  $('#nextBtn').classList.add('hidden');
  const box=$('#opts'); box.innerHTML='';
  q.options.forEach((opt,i)=>{
    const d=document.createElement('div'); d.className='opt';
    d.innerHTML='<span class="k">'+LETTERS[i]+'.</span><span>'+md(opt)+'</span>';
    d.onclick=()=>choose(i,d);
    box.appendChild(d);
  });
}

function choose(i,el){
  if(answered) return;
  answered=true;
  const q=quiz[cur];
  const mode=$('#mode').value;
  const nodes=$('#opts').querySelectorAll('.opt');
  nodes.forEach(n=>n.classList.add('disabled'));
  if(i===q.correct){ score++; el.classList.add('correct'); }
  else {
    el.classList.add('wrong');
    wrongs.push({q:q.q, your:q.options[i], correct:q.options[q.correct], cl:LETTERS[i], cc:LETTERS[q.correct]});
    if(mode==='instant') nodes[q.correct].classList.add('correct');
  }
  $('#qscore').textContent='คะแนน '+score;
  if(mode==='instant' && q.explain){
    $('#explain').innerHTML='<strong>เฉลย:</strong> '+md(q.explain);
    $('#explain').classList.remove('hidden');
  }
  $('#nextBtn').classList.remove('hidden');
  $('#nextBtn').textContent = (cur===quiz.length-1)?'ดูผลคะแนน ✓':'ถัดไป →';
}

function nextQ(){
  if(cur<quiz.length-1){ cur++; renderQ(); }
  else showResult();
}

function showResult(){
  $('#quiz').classList.add('hidden');
  $('#result').classList.remove('hidden');
  const pct=Math.round(score/quiz.length*100);
  $('#scoreNum').textContent=score+' / '+quiz.length;
  let g, color;
  if(pct>=90){g='🏆 ยอดเยี่ยม! แม่นมาก';color='var(--good)';}
  else if(pct>=70){g='👍 ดี ทบทวนข้อที่ผิดอีกนิด';color='var(--accent)';}
  else if(pct>=50){g='📖 พอใช้ ควรอ่านสรุปเพิ่ม';color='#fbbf24';}
  else {g='💪 สู้ๆ อ่านสรุปเนื้อหาแล้วลองใหม่';color='var(--bad)';}
  $('#grade').innerHTML='<span style="color:'+color+'">'+g+' ('+pct+'%)</span>';
  const rv=$('#review'); rv.innerHTML='';
  if(wrongs.length){
    rv.innerHTML='<div style="text-align:left;color:var(--muted);margin-bottom:8px">ข้อที่ตอบผิด ('+wrongs.length+'):</div>';
    wrongs.forEach(w=>{
      const d=document.createElement('div'); d.className='review-item';
      d.innerHTML='<div class="q">'+md(w.q)+'</div>'+
        '<div class="ans">คุณตอบ '+w.cl+'. '+md(w.your)+'</div>'+
        '<div class="cor">เฉลย '+w.cc+'. '+md(w.correct)+'</div>';
      rv.appendChild(d);
    });
  } else {
    rv.innerHTML='<div style="color:var(--good)">ตอบถูกทุกข้อ 🎉</div>';
  }
}

$('#startBtn').onclick=start;
$('#nextBtn').onclick=nextQ;
$('#againBtn').onclick=()=>{ $('#result').classList.add('hidden'); $('#setup').classList.remove('hidden'); renderSetup(); };
renderSetup();
</script>
</body>
</html>
'@

$html = $html.Replace('/*QUIZ_JSON*/', $json)

$out = Join-Path $root 'แบบทดสอบ.html'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $html, $utf8)

Write-Host ""
Write-Host "สร้างไฟล์เรียบร้อย -> $out" -ForegroundColor Green
Write-Host "ดับเบิลคลิกไฟล์ แบบทดสอบ.html เพื่อเริ่มทำข้อสอบได้เลย"
