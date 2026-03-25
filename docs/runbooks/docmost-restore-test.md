# Docmost Restore Test

## Scope

This runbook documents a safe restore drill for the `docmost` app in namespace `apps`.

It covers restoring:

- the Docmost filesystem data from the VolSync/restic backup of PVC `docmost-data`
- the PostgreSQL database from the CloudNativePG backup stored in Garage

This procedure does not cut production over. It restores into throwaway resources only:

- PVC `docmost-data-restore`
- CNPG cluster `docmost-postgres-restore`
- temporary app `docmost-restore-test`

## Repo Files Used

- [kubernetes/apps/docmost/restore-drill/restore.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/restore-drill/restore.yaml)
- [kubernetes/apps/docmost/restore-drill/restore-test.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/restore-drill/restore-test.yaml)
- [kubernetes/apps/docmost/app.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/app.yaml)
- [kubernetes/apps/docmost/postgres.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/postgres.yaml)
- [kubernetes/apps/docmost/volsync.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/volsync.yaml)
- [kubernetes/apps/docmost/externalsecrets.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/externalsecrets.yaml)

## Current Backup Inputs

Docmost app data:

- Namespace: `apps`
- PVC: `docmost-data`
- VolSync `ReplicationSource`: `docmost-data`
- Restic repository secret: `docmost-data-restic-config`
- Restic repository path: `/mnt/repo/docmost-data`
- Backup schedule: `0 3 * * *`

Docmost PostgreSQL:

- Namespace: `apps`
- CNPG cluster: `docmost-postgres`
- ScheduledBackup: `docmost-postgres-backup`
- Backup destination: `s3://cnpg-backups/docmost`
- Backup endpoint: `http://garage.garage.svc.cluster.local:3900`
- Barman server name: `docmost-postgres`

## Prerequisites

- Argo CD is healthy and syncing this repo.
- VolSync, CloudNativePG, Garage, External Secrets, Longhorn, and Docmost are healthy.
- The existing secrets are present in `apps`:
  - `docmost-data-restic-config`
  - `docmost-postgres-auth`
  - `docmost-postgres-backup-s3`
  - `docmost-app-secrets`
- `docmost-redis` remains available during the restore test.
- You have `kubectl` access to the cluster.

Useful checks:

```bash
kubectl -n apps get pvc docmost-data
kubectl -n apps get replicationsource docmost-data
kubectl -n apps get scheduledbackup docmost-postgres-backup
kubectl -n apps get secret docmost-data-restic-config docmost-postgres-auth docmost-postgres-backup-s3 docmost-app-secrets
kubectl -n apps get svc docmost-redis
```

## Enable The Restore Test Resources

The restore manifests are intentionally not part of the default Docmost Kustomization. Enable them temporarily through GitOps.

Edit [kubernetes/apps/docmost/kustomization.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/kustomization.yaml) and add:

```yaml
resources:
  - externalsecrets.yaml
  - postgres.yaml
  - redis.yaml
  - app.yaml
  - volsync.yaml
  - restore-drill/restore.yaml
  - restore-drill/restore-test.yaml
```

Commit and push that temporary change, then wait for Argo CD to sync it.

## Step 1: Restore The VolSync PVC Backup

The restore target is defined in [kubernetes/apps/docmost/restore-drill/restore.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/restore-drill/restore.yaml):

- PVC `docmost-data-restore`
- `ReplicationDestination` `docmost-data-restore`

To trigger a restore, update the manual trigger value in that file. Change:

```yaml
spec:
  trigger:
    manual: restore-once
```

to a unique value for this run, for example:

```yaml
spec:
  trigger:
    manual: restore-2026-03-25
```

Commit and push that change, then watch the restore:

```bash
kubectl -n apps get pvc docmost-data-restore
kubectl -n apps get replicationdestination docmost-data-restore -o yaml
kubectl -n apps get pods -w
```

Wait until:

- PVC `docmost-data-restore` is `Bound`
- the VolSync restore job completes
- `ReplicationDestination/docmost-data-restore` shows a successful latest status

If you need another restore run later, change `spec.trigger.manual` to a new string again.

## Step 2: Restore The CNPG Backup Into A Throwaway Cluster

The throwaway database cluster is defined in [kubernetes/apps/docmost/restore-drill/restore-test.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/restore-drill/restore-test.yaml) as `docmost-postgres-restore`.

It restores from the same Garage backup location used by production:

- destination path `s3://cnpg-backups/docmost`
- server name `docmost-postgres`
- secret `docmost-postgres-backup-s3`

Watch the recovery cluster:

```bash
kubectl -n apps get cluster docmost-postgres-restore
kubectl -n apps get pods -l cnpg.io/cluster=docmost-postgres-restore -w
kubectl -n apps get svc docmost-postgres-restore-rw
```

Wait until:

- the CNPG cluster reports ready
- the primary pod for `docmost-postgres-restore` is running
- service `docmost-postgres-restore-rw` exists

Optional SQL sanity check:

```bash
kubectl -n apps exec -it docmost-postgres-restore-1 -- \
  psql -U docmost -d docmost -c '\dt'
```

If the pod name differs, use `kubectl -n apps get pods -l cnpg.io/cluster=docmost-postgres-restore`.

## Step 3: Start A Temporary Docmost Instance Against The Restored Data

The temporary app is also defined in [kubernetes/apps/docmost/restore-drill/restore-test.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/restore-drill/restore-test.yaml):

- Deployment `docmost-restore-test`
- Service `docmost-restore-test`
- uses PVC `docmost-data-restore`
- uses database host `docmost-postgres-restore-rw.apps.svc.cluster.local`
- reuses existing Redis `docmost-redis`
- does not create an `HTTPRoute`

Watch rollout:

```bash
kubectl -n apps rollout status deploy/docmost-restore-test
kubectl -n apps get pods -l app=docmost-restore-test
kubectl -n apps get svc docmost-restore-test
```

Access it locally without exposing it publicly:

```bash
kubectl -n apps port-forward svc/docmost-restore-test 3001:3000
```

Then open:

```text
http://127.0.0.1:3001
```

## Step 4: Verify The Restore

Call the restore successful only if all of the following are true:

- the restore PVC exists and contains expected Docmost file data
- the throwaway CNPG cluster reaches ready state
- the temporary Docmost pod becomes ready
- the temporary Docmost UI loads through the local port-forward
- you can log in with a known working Docmost account
- expected workspaces, pages, uploads, and attachments are present
- opening a page that references uploaded content works
- recent data looks plausible relative to the backup schedule

Useful checks:

```bash
kubectl -n apps exec deploy/docmost-restore-test -- ls -lah /app/data/storage
kubectl -n apps exec deploy/docmost-restore-test -- sh -c 'find /app/data/storage -maxdepth 2 | head -50'
kubectl -n apps logs deploy/docmost-restore-test --tail=100
kubectl -n apps logs docmost-postgres-restore-1 --tail=100
```

## Cleanup

After the test, remove the temporary resources through GitOps.

1. Revert [kubernetes/apps/docmost/kustomization.yaml](/home/andre/code/ew/erasmus.works/kubernetes/apps/docmost/kustomization.yaml) so it no longer includes:
   - `restore-drill/restore.yaml`
   - `restore-drill/restore-test.yaml`
2. Commit and push the revert.
3. Wait for Argo CD to prune:
   - `docmost-data-restore`
   - `docmost-data-restore` `ReplicationDestination`
   - `docmost-postgres-restore`
   - `docmost-restore-test`
4. Confirm cleanup:

```bash
kubectl -n apps get pvc docmost-data-restore
kubectl -n apps get replicationdestination docmost-data-restore
kubectl -n apps get cluster docmost-postgres-restore
kubectl -n apps get deploy docmost-restore-test
kubectl -n apps get svc docmost-restore-test
```

## Notes

- This runbook intentionally avoids modifying:
  - production deployment `docmost`
  - production cluster `docmost-postgres`
  - production PVC `docmost-data`
- `restore-drill/restore.yaml` uses a manual VolSync trigger. Re-running the drill requires a new trigger string.
- The temporary app reuses the existing Redis service. This is acceptable for a restore test because no production traffic is routed to the temporary app.
- The temporary app reuses the existing Docmost app secret and database credentials. No new secrets are required for the drill.
