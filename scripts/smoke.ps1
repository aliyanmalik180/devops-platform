# End-to-end check: create a link, click it twice, expect clicks == 2.
# Docker Compose: -BaseUrl http://localhost:8080   Kubernetes (kind): http://localhost:8081
param([string]$BaseUrl = "http://localhost:8081")
$ErrorActionPreference = "Stop"

$r = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/shorten" -ContentType "application/json" -Body '{"url":"https://example.com"}'
Write-Host "Created code: $($r.code)"
1..2 | ForEach-Object {
    Invoke-WebRequest -Uri "$BaseUrl/$($r.code)" -MaximumRedirection 0 -ErrorAction SilentlyContinue | Out-Null
}
Start-Sleep 3
$s = Invoke-RestMethod "$BaseUrl/api/urls/$($r.code)"
if ($s.clicks -eq 2) {
    Write-Host "PASS: clicks = 2 (api -> redis -> worker -> postgres works)" -ForegroundColor Green
} else {
    Write-Host "FAIL: clicks = $($s.clicks), expected 2" -ForegroundColor Red
    exit 1
}
