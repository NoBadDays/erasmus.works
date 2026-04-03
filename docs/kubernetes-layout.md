# Kubernetes Layout

## Purpose

Keep cluster wiring separate from deployable components.

## Rules

- `kubernetes/clusters/homelab/argocd-apps/` contains only top-level Argo CD `Application` manifests for this cluster.
- `kubernetes/infra/` contains shared platform services other workloads depend on.
- `kubernetes/apps/` contains user-facing workloads.

## Classification

- Put a component in `infra/` when it provides a shared capability such as identity, ingress, storage, DNS, monitoring, or backups.
- Put a component in `apps/` when you primarily run it for its own end-user function.
- User-visible does not automatically mean `apps/`. Shared services like Authentik still belong in `infra/`.
