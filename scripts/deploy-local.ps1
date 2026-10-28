# Builds the 3 images, loads them into kind and installs the Helm chart.
# No registry or GitHub needed. Tags are unique per run (never "latest").
. "$PSScriptRoot\common.ps1"
Test-Prereqs @("docker", "kind", "kubectl", "helm")
Use-KindContext

$tag = "local-" + (Get-Date -Format "yyyyMMddHHmmss")
foreach ($s in "api", "worker", "frontend") {
    Invoke-Step "Building shortener-${s}:$tag" { docker build -t "shortener-${s}:$tag" "$RepoRoot\app\$s" }
    Invoke-Step "Loading shortener-${s}:$tag into kind" { kind load docker-image "shortener-${s}:$tag" --name $ClusterName }
}

$sets = @(
    "--set", "api.image.repository=shortener-api",           "--set", "api.image.tag=$tag",
    "--set", "worker.image.repository=shortener-worker",     "--set", "worker.image.tag=$tag",
    "--set", "frontend.image.repository=shortener-frontend","--set", "frontend.image.tag=$tag"
)
Invoke-Step "helm upgrade --install (waits until everything is ready)" {
    helm upgrade --install shortener "$RepoRoot\deploy\helm\shortener" `
        --namespace shortener --create-namespace @sets --wait --timeout 5m
}

Write-Host ""
Write-Host "  App ready" -ForegroundColor Green
Write-Host ""
Write-Host "  Website:  http://localhost:8081"
Write-Host "  Pods:     kubectl get pods -n shortener"
Write-Host "  Test:     .\scripts\smoke.ps1 -BaseUrl http://localhost:8081"
