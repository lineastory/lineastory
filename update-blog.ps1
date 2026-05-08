# 블로그 최근 소식 업데이트 스크립트
# 더블클릭(또는 우클릭→PowerShell로 실행)하면 네이버 블로그 RSS를 받아
# data/recent-posts.json을 갱신하고 GitHub에 푸시합니다.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  블로그 최근 소식 업데이트" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "[1/4] 네이버 블로그 RSS 가져오는 중..." -ForegroundColor Yellow
    $url = "https://api.rss2json.com/v1/api.json?rss_url=https%3A%2F%2Frss.blog.naver.com%2Fheartart1.xml"
    $r = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec 30
    if ($r.status -ne "ok") { throw "RSS 가져오기 실패: $($r.status)" }

    $items = $r.items | Select-Object -First 6 | ForEach-Object {
        $desc = $_.description -replace '<[^>]*>', ' ' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#39;', "'" -replace '\s+', ' '
        $desc = $desc.Trim()
        if ($desc.Length -gt 200) { $desc = $desc.Substring(0, 200).Trim() + '…' }
        $title = ($_.title -replace '<[^>]*>', ' ' -replace '\s+', ' ').Trim()
        [pscustomobject]@{
            title = $title
            link = $_.link
            pubDate = $_.pubDate
            thumbnail = if ($_.thumbnail) { $_.thumbnail } else { '' }
            description = $desc
        }
    }

    Write-Host "  -> $($items.Count)개 글 가져옴" -ForegroundColor Gray

    Write-Host "[2/4] data/recent-posts.json 업데이트 중..." -ForegroundColor Yellow
    $out = [pscustomobject]@{
        updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        items = $items
    }
    $json = $out | ConvertTo-Json -Depth 5
    $jsonPath = Join-Path $repoRoot "data\recent-posts.json"
    if (-not (Test-Path (Split-Path $jsonPath))) { New-Item -ItemType Directory -Path (Split-Path $jsonPath) | Out-Null }
    [System.IO.File]::WriteAllText($jsonPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  -> 저장 완료" -ForegroundColor Gray

    # git은 경고도 stderr로 보내므로 ErrorActionPreference를 일시 완화
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    Write-Host "[3/4] Git 커밋 중..." -ForegroundColor Yellow
    & git add "data/recent-posts.json" 2>&1 | Out-Null
    & git diff --cached --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  -> 변경사항 없음. 종료합니다." -ForegroundColor Yellow
        Write-Host ""
        $ErrorActionPreference = $prevPref
        Read-Host "엔터를 눌러 닫기"
        exit 0
    }
    & git commit -m "Refresh blog feed snapshot" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git commit 실패" }
    Write-Host "  -> 커밋 완료" -ForegroundColor Gray

    Write-Host "[4/4] GitHub에 푸시 중..." -ForegroundColor Yellow
    & git push origin main 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git push (main) 실패" }
    & git push origin main:claude/dazzling-greider-18ea41 --force 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git push (claude branch) 실패" }
    Write-Host "  -> 푸시 완료" -ForegroundColor Gray

    $ErrorActionPreference = $prevPref

    Write-Host ""
    Write-Host "✓ 모든 작업이 완료되었습니다!" -ForegroundColor Green
    Write-Host "  1~3분 후 https://lineastory.github.io/lineastory/ 에 반영됩니다." -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "❌ 오류 발생: $_" -ForegroundColor Red
    Write-Host ""
}

Read-Host "엔터를 눌러 닫기"
