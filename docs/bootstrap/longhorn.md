# Longhorn Bootstrap Notes

## Scope

This note covers the repo-side Longhorn install and the Talos prerequisites that must exist before the Argo CD application can become healthy.

## Repo-side Install

Longhorn is registered through Argo CD from `kubernetes/infra/longhorn/application.yaml`.

After the repo change is pushed and synced, verify:

```bash
export KUBECONFIG=~/code/erasmus.works/talos/kubeconfig

kubectl -n argocd get applications
kubectl -n longhorn-system get pods
kubectl get storageclass
```

## Talos Prerequisites

Longhorn on Talos requires more than just the Kubernetes manifests.

- The Talos image must include `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`.
- The kubelet must bind-mount `/var/lib/longhorn` so Longhorn can access the host path.
- The `longhorn-system` namespace must remain `privileged`.

This repo now includes:

- image-factory schematic: `talos/image-factory/longhorn.yaml`
- kubelet mount changes in `talos/node-01/controlplane.yaml`
- kubelet mount changes in `talos/node-01/worker.yaml`

The current node uses a single 512 GB SSD and Talos has already allocated almost the whole disk to `EPHEMERAL` (`/dev/nvme0n1p4` at about 510 GB). Because of that, this repo intentionally keeps Longhorn on `/var/lib/longhorn` on the existing Talos `EPHEMERAL` volume instead of trying to add a new `UserVolumeConfig` that the disk layout cannot currently satisfy without repartitioning or reinstalling the node.

## Generate The Image Factory ID

Upload the committed schematic and capture the returned ID:

```bash
cd ~/code/erasmus.works
curl -X POST --data-binary @talos/image-factory/longhorn.yaml https://factory.talos.dev/schematics
```

The response shape is:

```json
{"id":"<schematic-id>"}
```

That ID is the value used in the Talos installer image:

`factory.talos.dev/installer/<schematic-id>:v1.12.4`

## Apply The Talos Changes

1. The committed Talos configs already reference schematic ID `613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245`.
2. Apply the updated machine config.
3. Upgrade the node to the custom installer image so the system extensions are actually installed.
4. Reboot and verify the new image and kubelet mount before expecting Longhorn to become healthy.

Example:

```bash
export CONTROL_PLANE_IP=192.168.20.33
export SCHEMATIC_ID=replace_me

talosctl apply-config \
  --nodes "$CONTROL_PLANE_IP" \
  --endpoints "$CONTROL_PLANE_IP" \
  --talosconfig ./talos/node-01/talosconfig \
  --file ./talos/node-01/controlplane.yaml

talosctl upgrade \
  --nodes "$CONTROL_PLANE_IP" \
  --endpoints "$CONTROL_PLANE_IP" \
  --talosconfig ./talos/node-01/talosconfig \
  --image "factory.talos.dev/installer/${SCHEMATIC_ID}:v1.12.4"
```

## Useful Checks

Once the Talos changes are applied and the node has rebooted, validate the environment before troubleshooting Longhorn itself:

```bash
talosctl get extensions --nodes 192.168.20.33 --endpoints 192.168.20.33 --talosconfig ./talos/node-01/talosconfig
talosctl mounts --nodes 192.168.20.33 --endpoints 192.168.20.33 --talosconfig ./talos/node-01/talosconfig
kubectl -n longhorn-system get pods
kubectl get nodes -o wide
```

Official references:

- https://longhorn.io/docs/latest/deploy/install/install-with-argocd/
- https://longhorn.io/docs/latest/deploy/install/
- https://longhorn.io/docs/1.10.0/advanced-resources/os-distro-specific/talos-linux-support/
