# GitOps mode: installs Argo CD and registers the shortener-dev Application.
# Argo CD then deploys whatever is in GitHub (deploy/helm + gitops/dev/values.yaml).
. "$PSScriptRoot\common.ps1"
Test-Prereqs @("kubectl", "helm")
Use-KindContext

helm status shortener -n shortener 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "A Helm release 'shortener' (from deploy-local.ps1) already exists." -ForegroundColor Red
    Write-Host "Run: helm uninstall shortener -n shortener   (then run this script again)" -ForegroundColor Yellow
    exit 1
}

Invoke-Step "Creating namespace argocd" { kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - }
Invoke-Step "Installing Argo CD (server-side apply, CRDs are large)" {
    kubectl apply -n argocd --server-side --force-conflicts -f $ArgoCdUrl
}
Invoke-Step "Waiting for argocd-server" { kubectl rollout status deployment/argocd-server -n argocd --timeout=300s }
Invoke-Step "Registering Application shortener-dev" { kubectl apply -f "$RepoRoot\gitops\apps\shortener-dev.yaml" }

$b64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$pw  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))

Write-Host ""
Write-Host "  Argo CD ready" -ForegroundColor Green
Write-Host ""
Write-Host "  1. In another terminal run:  kubectl port-forward svc/argocd-server -n argocd 8443:443"
Write-Host "  2. Open:      https://localhost:8443   (accept the browser warning)"
Write-Host "  3. Login:     admin / $pw"
Write-Host ""
Write-Host "  The app shows ImagePullBackOff until real image tags are set."
Write-Host "  GitHub -> Actions -> gitops-bump -> Run workflow (paste a commit SHA), or push to main."
