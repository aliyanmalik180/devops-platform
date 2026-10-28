# 5. GitOps with Argo CD and a Helm chart
Status: Accepted

**Context:** Deployments must be reviewable, repeatable and revertible.
**Decision:** One Helm chart (`deploy/helm/shortener`). Git is the source of truth: Argo CD syncs the chart plus `gitops/dev/values.yaml`. After CI publishes images, `gitops-bump` commits the commit SHA into that values file (commit message contains `[skip ci]` and uses `GITHUB_TOKEN`, so no CI loop).
**Alternatives:** `helm upgrade` from CI (needs cluster credentials in GitHub, no drift correction); Flux (equivalent).
**Consequences:** Rollback is `git revert`. The cluster never needs inbound access from CI. Staging/prod would add `gitops/staging` and `gitops/prod` values plus manual approval.
