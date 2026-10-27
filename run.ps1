docker compose up --build -d --wait

if ($LASTEXITCODE -ne 0) {
    Write-Host "Kuch masla aaya. Dekhein: docker compose logs" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  App ready" -ForegroundColor Green
Write-Host ""
Write-Host "  Website:  http://localhost:8080"
Write-Host "  API docs: http://localhost:8000/docs"
Write-Host ""
Write-Host "  Rokne ke liye: docker compose stop"