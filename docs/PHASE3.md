# Phase 3: Kubernetes (kind), Helm, Argo CD

Everything here is free and runs on your machine. Needs Docker Desktop and about 6 GB of free RAM.

## One-time install (Windows)
```powershell
winget install Kubernetes.kind Kubernetes.kubectl Helm.Helm
```
Open a **new** terminal afterwards. Stop docker compose first if it is running (`docker compose stop`) to save RAM.

## Mode A: local Helm deploy (no GitHub needed)
```powershell
.\scripts\kind-up.ps1        # cluster + metrics-server
.\scripts\deploy-local.ps1   # build, load, helm install
.\scripts\smoke.ps1          # expects: PASS: clicks = 2
```
Website: http://localhost:8081

## Mode B: GitOps with Argo CD (the real flow)
1. Make the three GHCR packages public (GitHub profile -> Packages -> each of `devops-platform/api`, `/worker`, `/frontend` -> Package settings -> Change visibility -> Public), so the cluster can pull them.
2. Push this phase to `main` and wait for `ci` to go green.
3. GitHub -> Actions -> `gitops-bump` -> Run workflow, paste the full SHA of the commit CI built (this also runs automatically after later CI runs on main).
4. `.\scripts\kind-up.ps1` then `.\scripts\argocd-up.ps1` (use Mode A **or** B in one cluster, not both).
5. Open the Argo CD UI as the script explains. `shortener-dev` should turn Synced and Healthy.
6. Change something (for example `api.replicas` in `gitops/dev/values.yaml`), push, and watch Argo CD apply it. That is GitOps.

## What to verify
```powershell
kubectl get pods -n shortener          # all Running / Ready
kubectl get hpa,pdb -n shortener       # HPA shows a CPU %, PDB shows ALLOWED DISRUPTIONS 1
kubectl get networkpolicy -n shortener
kubectl rollout restart deployment/api -n shortener   # zero-downtime rolling update
```

## Troubleshooting
| Symptom | Fix |
|---|---|
| `ImagePullBackOff` in Mode B | Package is private, or tag is still `bootstrap`. Make packages public and run `gitops-bump` |
| `CrashLoopBackOff` on frontend | Run `kubectl logs deploy/frontend -n shortener`. If it is a read-only filesystem error, set `readOnlyRootFilesystem: false` for that container in `templates/frontend.yaml` |
| HPA shows `<unknown>` | metrics-server is not ready yet. `kubectl top pods -n shortener` must work |
| Port 8081 already in use | Change `hostPort` in `deploy/kind/kind-config.yaml`, recreate the cluster |
| Argo CD cannot find `../../../gitops/dev/values.yaml` | Make sure `gitops/dev/values.yaml` is pushed to `main` |
| `kind create cluster` fails | Check Docker Desktop is running (WSL2 backend) and has enough memory |

## Clean up
```powershell
.\scripts\kind-down.ps1   # deletes the cluster; recreate any time
```
