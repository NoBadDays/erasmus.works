---
name: homelab-kubernetes-workspace
description: "Kubernetes homelab workspace rules: KISS principle, GitOps-only changes, inspect structure first, prefer Kustomize, Argo CD finalizers required. Use when: working with Kubernetes manifests, GitOps deployments, homelab infrastructure, or following project conventions."
applyTo: "**/*.{yaml,yml,json,md}"
---

# Homelab Kubernetes Workspace Instructions

## Core Principles
- **KISS**: Keep it simple, reproducible, low-maintenance
- **GitOps Only**: All cluster changes through this repo via Argo CD, never imperative `kubectl` commands
- **Inspect First**: Always examine existing structure, docs and patterns before making changes
- **Minimal Changes**: Keep modifications small and obvious

## Repository Structure
- `talos/`: Talos machine configs and node-specific files
- `kubernetes/`: GitOps-managed Kubernetes manifests
- `docs/`: Practical runbooks and setup notes
- `linux/`: Local workstation/helper setup files

## Kubernetes/GitOps Rules
- **Argo CD Root**: `kubernetes/clusters/homelab/homelab-root.yaml`
- **Infra Location**: All infrastructure components under `kubernetes/infra/`
- **Manifest Style**: Plain, readable manifests with Kustomize preferred over Helm
- **Helm Values**: Use separate `values.yaml` files, not inline `helm.values` blocks
- **Argo CD Finalizers**: Always include `resources-finalizer.argocd.argoproj.io` in Application manifests
- **CNPG Backups**: Follow existing pattern - keep `ACCESS_KEY_ID` in Git, store only `ACCESS_SECRET_KEY` in Bitwarden/External Secrets
- **PVC Strategy**: Single-replica Deployments with `ReadWriteOnce` PVCs should use `Recreate` over `RollingUpdate`

## Change Rules
1. Inspect existing structure first
2. Reuse existing folders and patterns
3. Keep changes minimal and obvious
4. Don't rename/move files unless clear benefit
5. Don't introduce unnecessary docs

## Documentation Rules
- Root README stays short as project overview
- Command-heavy instructions belong in docs/, not README
- Keep documents succinct and practical
- Add short practical notes, not large architecture essays
- Avoid creating new docs unless real need

## Naming Guidance
- Use clear, literal names
- Match filenames to actual contents
- Avoid vague names like `stuff.yaml`, `test2.yaml`, `misc.md`
- Prefer consistency over cleverness

## When Unsure
Prefer the simpler option. Do not overengineer.
