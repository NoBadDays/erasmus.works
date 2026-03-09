# erasmus.works

Homelab Kubernetes repo for a Talos cluster, with a simple GitOps workflow using Argo CD.

## Repository Structure

```text
.
├── kubernetes/
│   ├── bootstrap/argocd/      # Argo CD install bootstrap
│   ├── clusters/homelab/      # Cluster entrypoint (root app + cluster-level Argo CD Applications)
│   ├── infra/                 # Infra-only manifests and infra-related Argo CD Application objects
│   └── apps/                  # App runtime manifests
├── talos/
│   └── node-01/               # Talos node-specific generated configs
├── linux/                     # Local workstation bootstrap helpers
└── docs/                      # Project docs and runbooks
```

## GitOps Flow

1. Install Argo CD with `kubernetes/bootstrap/argocd/bootstrap-argocd.sh`.
2. Apply `kubernetes/clusters/homelab/root-app.yaml`.
3. The root app syncs `kubernetes/clusters/homelab`, which registers cluster-level child Applications.
4. Child Applications sync:
   - `kubernetes/infra` for infra components.
   - `kubernetes/apps/homepage` for Homepage.

Homepage is the current example app managed through Argo CD and exposed at `homepage.homelab`.

## Documentation

- [Talos Bootstrap Runbook](docs/bootstrap/talos.md)
- [Argo CD Bootstrap Runbook](docs/bootstrap/argocd.md)
- [Linux Init Script](linux/init.md)
