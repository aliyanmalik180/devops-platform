# 4. Run Kubernetes locally with kind first
Status: Accepted

**Context:** A managed cluster (EKS) costs money every hour and needs a cloud account. Reviewers should be able to reproduce the project for free.
**Decision:** Target `kind` (Kubernetes in Docker) for Helm, GitOps and policy work. Cloud IaC (Terraform) is written separately and does not block this phase.
**Alternatives:** EKS/GKE (cost, account required), minikube/k3d (equivalent; kind chosen for CI parity and simple multi-node config).
**Consequences:** Same manifests and chart work on a cloud cluster; only storage, ingress and the managed database/cache differ (`postgres.enabled` and `redis.enabled` switch the in-cluster ones off).
