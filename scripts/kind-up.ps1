# Creates the local kind cluster and installs metrics-server (needed by the HPA).
. "$PSScriptRoot\common.ps1"
Test-Prereqs @("docker", "kind", "kubectl", "helm")

$existing = kind get clusters 2>$null
if ($existing -contains $ClusterName) {
    Write-Host "Cluster '$ClusterName' already exists, skipping create." -ForegroundColor Yellow
} else {
    Invoke-Step "Creating kind cluster '$ClusterName' (first time takes a few minutes)" {
        kind create cluster --name $ClusterName --config "$RepoRoot\deploy\kind\kind-config.yaml"
    }
}
Use-KindContext
Invoke-Step "Installing metrics-server" { kubectl apply -f $MetricsServerUrl }
Invoke-Step "Patching metrics-server for kind" {
    kubectl patch deployment metrics-server -n kube-system --type=json --patch-file "$RepoRoot\deploy\kind\metrics-server-patch.json"
}
Invoke-Step "Waiting for metrics-server" { kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s }

Write-Host ""
Write-Host "Cluster ready." -ForegroundColor Green
Write-Host "Next (pick ONE):"
Write-Host "  .\scripts\deploy-local.ps1     # build images locally and install with Helm"
Write-Host "  .\scripts\argocd-up.ps1        # GitOps: Argo CD deploys from GitHub"
