# 3. GHCR registry and Git-SHA image tags
Status: Accepted

**Context:** Deployments must be traceable and reproducible.
**Decision:** Push to GHCR with `${{ github.sha }}` tags only; `latest` is never produced or deployed. SBOM and provenance attestations at build; Cosign signing added in Phase 5.
**Consequences:** Every running pod maps to one commit. Rollback = redeploy an earlier SHA.
