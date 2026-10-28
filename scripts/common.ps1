# Shared helpers. Dot-source from the other scripts:  . "$PSScriptRoot\common.ps1"
$ClusterName      = "shortener"
$KubeContext      = "kind-$ClusterName"
$RepoRoot         = Split-Path -Parent $PSScriptRoot
$MetricsServerUrl = "https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml"
$ArgoCdUrl        = "https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml"

function Test-Prereqs([string[]]$Tools) {
    $missing = $Tools | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
    if ($missing) {
        Write-Host "Missing tools: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "Install with: winget install Kubernetes.kind Kubernetes.kubectl Helm.Helm" -ForegroundColor Yellow
        Write-Host "Then open a NEW terminal and run again." -ForegroundColor Yellow
        exit 1
    }
}

function Invoke-Step([string]$Description, [scriptblock]$Command) {
    Write-Host "==> $Description" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Description" -ForegroundColor Red
        exit 1
    }
}

# Never deploy to the wrong cluster by accident.
function Use-KindContext {
    Invoke-Step "Selecting kubectl context $KubeContext" { kubectl config use-context $KubeContext }
}
