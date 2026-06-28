# ============================================================
#  สร้างไฟล์ หน้าแรก.html (เมนูหลักเชื่อมทุกโปรแกรม)
#  วิธีใช้: คลิกขวาที่ไฟล์นี้ > Run with PowerShell
#  แนะนำให้รัน _สร้างแฟลชการ์ด.ps1 และ _สร้างแบบทดสอบ.ps1 ก่อน
#  เพื่อให้ตัวเลขจำนวนการ์ด/ข้อสอบบนหน้าแรกอัปเดตถูกต้อง
# ============================================================

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Count-FromHtml($file, $varName, $itemField) {
    # อ่านจำนวนรายการรวมจาก JSON ที่ฝังในไฟล์ html
    $p = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $line = Select-String -LiteralPath $p -Pattern ("^const $varName = ") | Select-Object -First 1
    if (-not $line) { return $null }
    $json = $line.Line -replace "^const $varName = ",'' -replace ';$',''
    try {
        $o = $json | ConvertFrom-Json
        return ($o | ForEach-Object { $_.$itemField.Count } | Measure-Object -Sum).Sum
    } catch { return $null }
}

$fcCount = Count-FromHtml 'แฟลชการ์ด.html' 'DECKS'   'cards'
$qzCount = Count-FromHtml 'แบบทดสอบ.html'  'QUIZZES' 'questions'
$fcText = if ($fcCount) { "$fcCount ใบ · 5 หัวข้อ" } else { "เปิดเพื่อทบทวน" }
$qzText = if ($qzCount) { "$qzCount ข้อ · 6 ชุด (รวมข้อสอบจำลอง)" } else { "เปิดเพื่อทำข้อสอบ" }

# หัวข้อ + ไฟล์สรุป (สำหรับลิงก์อ่านเนื้อหา)
$topics = @(
    @{ name = 'PDPA';                 folder = '1_PDPA' }
    @{ name = 'พ.ร.บ.คอม / ไซเบอร์';   folder = '2_พรบคอม-ไซเบอร์' }
    @{ name = 'ทรัพย์สินทางปัญญา';     folder = '3_ทรัพย์สินทางปัญญา' }
    @{ name = 'AI Law & Ethics';      folder = '4_AI' }
    @{ name = 'ธุรกรรมอิเล็กทรอนิกส์';  folder = '5_ธุรกรรมอิเล็กทรอนิกส์' }
    @{ name = 'คลังเคส & ข้อสอบรวม';   folder = '6_คลังเคส_ข้อสอบรวม' }
)

function Enc($relPath) {
    # encode ทีละ segment คงเครื่องหมาย /
    ($relPath -split '[\\/]' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

$topicLinks = ''
foreach ($t in $topics) {
    $dir = Join-Path $root $t.folder
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    # ไฟล์สรุปหลัก (01_*) ถ้ามี ไม่งั้นลิงก์ไปไฟล์แรก
    $summary = Get-ChildItem -LiteralPath $dir -Filter '01_*.md' | Select-Object -First 1
    $href = if ($summary) { Enc("$($t.folder)/$($summary.Name)") } else { Enc($t.folder) }
    $topicLinks += "      <a class=""topic"" href=""$href"">$($t.name)</a>`n"
}

$html = @"
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ศูนย์เรียนรู้ – จริยธรรมและกฎหมายไซเบอร์ 4231301</title>
<style>
  :root{--bg:#0f172a;--panel:#1e293b;--txt:#e2e8f0;--accent:#38bdf8;--muted:#94a3b8;--line:#334155}
  *{box-sizing:border-box}
  body{margin:0;font-family:"Sarabun","Segoe UI",Tahoma,sans-serif;background:
       radial-gradient(1200px 600px at 50% -10%,#1e3a5f33,transparent),var(--bg);
       color:var(--txt);min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:30px 18px 50px}
  .code{color:var(--accent);font-weight:700;letter-spacing:1px;font-size:13px}
  h1{font-size:25px;margin:6px 0 4px;text-align:center}
  .sub{color:var(--muted);font-size:14px;margin-bottom:30px;text-align:center;max-width:560px;line-height:1.6}
  .cards{display:flex;gap:18px;flex-wrap:wrap;justify-content:center;width:min(720px,96vw)}
  .card{flex:1 1 300px;background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:26px 24px;
        text-decoration:none;color:var(--txt);transition:.18s;display:block;position:relative;overflow:hidden}
  .card:hover{transform:translateY(-3px);border-color:var(--accent);box-shadow:0 16px 36px rgba(0,0,0,.4)}
  .card .ico{font-size:40px;margin-bottom:10px}
  .card .ttl{font-size:20px;font-weight:700;margin-bottom:6px}
  .card .desc{font-size:14px;color:var(--muted);line-height:1.55}
  .card .go{margin-top:16px;display:inline-block;background:var(--accent);color:#03263a;font-weight:700;
            border-radius:10px;padding:9px 16px;font-size:14px}
  .sect{width:min(720px,96vw);margin-top:34px}
  .sect h2{font-size:16px;color:var(--muted);font-weight:600;margin:0 0 12px;text-align:center}
  .topics{display:flex;flex-wrap:wrap;gap:10px;justify-content:center}
  .topic{background:#0b1220;border:1px solid var(--line);border-radius:999px;padding:9px 16px;font-size:14px;
         color:var(--txt);text-decoration:none;transition:.15s}
  .topic:hover{border-color:var(--accent);color:var(--accent)}
  .foot{margin-top:36px;color:#64748b;font-size:12px;text-align:center;line-height:1.7;max-width:560px}
  .how{background:#0b122088;border:1px dashed var(--line);border-radius:12px;padding:14px 18px;margin-top:22px;
       width:min(720px,96vw);color:var(--muted);font-size:13px;line-height:1.7}
  .how b{color:var(--txt)}
</style>
</head>
<body>
  <div class="code">รายวิชา 4231301</div>
  <h1>📚 ศูนย์เรียนรู้ จริยธรรมและกฎหมายไซเบอร์</h1>
  <div class="sub">เลือกเครื่องมือทบทวนด้านล่าง — ทุกอย่างทำงานในเครื่อง เปิดออฟไลน์ได้ ไม่ต้องติดตั้งโปรแกรมเพิ่ม</div>

  <div class="cards">
    <a class="card" href="แฟลชการ์ด.html">
      <div class="ico">🔑</div>
      <div class="ttl">แฟลชการ์ด</div>
      <div class="desc">ท่องจำแบบถาม–ตอบ พลิกการ์ดดูคำตอบ ทำเครื่องหมาย "รู้แล้ว / ยังไม่รู้" จับเฉพาะที่ยังไม่แม่น</div>
      <div class="desc" style="margin-top:8px;color:var(--accent)">$fcText</div>
      <span class="go">เริ่มทบทวน ▶</span>
    </a>
    <a class="card" href="แบบทดสอบ.html">
      <div class="ico">📝</div>
      <div class="ttl">แบบทดสอบ</div>
      <div class="desc">ทำข้อสอบปรนัยจากคลังข้อสอบจริง มีเฉลย+คำอธิบาย เลือกหัวข้อ/จำนวนข้อ มีโหมดจำลองสอบ</div>
      <div class="desc" style="margin-top:8px;color:var(--accent)">$qzText</div>
      <span class="go">เริ่มทำข้อสอบ ▶</span>
    </a>
  </div>

  <div class="sect">
    <h2>📖 อ่านสรุปเนื้อหาแต่ละหัวข้อ</h2>
    <div class="topics">
$topicLinks    </div>
  </div>

  <div class="how">
    <b>💡 การอัปเดตเนื้อหา:</b> หากแก้ไขไฟล์ <b>.md</b> (สรุป/แฟลชการ์ด/ข้อสอบ) แล้ว ให้รันสคริปต์
    <b>_สร้างแฟลชการ์ด.ps1</b> และ <b>_สร้างแบบทดสอบ.ps1</b> ใหม่ (คลิกขวา &gt; Run with PowerShell)
    จากนั้นรัน <b>_สร้างหน้าแรก.ps1</b> เพื่อรีเฟรชตัวเลขบนหน้านี้
  </div>

  <div class="foot">
    ไฟล์สรุปเนื้อหาเป็นรูปแบบ Markdown (.md) — เปิดอ่านได้ดีที่สุดในโปรแกรมแก้ไขข้อความหรือ Obsidian<br>
    สร้างจากชุดเรียนรู้ด้วยตนเอง · ใช้งานออฟไลน์ 100%
  </div>
</body>
</html>
"@

$out = Join-Path $root 'หน้าแรก.html'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $html, $utf8)

Write-Host "สร้างไฟล์เรียบร้อย -> $out" -ForegroundColor Green
Write-Host ("แฟลชการ์ด: {0} ใบ | แบบทดสอบ: {1} ข้อ" -f $fcCount, $qzCount)
Write-Host "ดับเบิลคลิก หน้าแรก.html เพื่อเข้าเมนูหลัก"
