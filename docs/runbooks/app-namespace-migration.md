# App Namespace Migration

This runbook covers the GitOps migration from the shared `apps` namespace to:

- `app-docmost`
- `app-homepage`
- `app-immich`
- `app-nextcloud`
- `authentik`

This is not a metadata-only change. For namespaced resources, Argo CD will create
new objects in the new namespace. It will not move existing StatefulSets, PVCs,
Secrets, or CNPG clusters across namespaces.

## Push Strategy

Do not push the namespace split straight to an auto-syncing cluster without a
maintenance window.

Do not take every app down before pushing as a blanket first step either.

Use this sequence instead:

1. Pause or disable auto-sync for the affected Argo CD Applications.
2. Take backups and confirm restore paths for each stateful app.
3. Cut over one app at a time.
4. Quiesce the specific app before its migration step.
5. Move or recreate data in the target namespace.
6. Re-enable sync and verify the app in the new namespace.

`homepage` is stateless and can move with minimal risk.

`docmost`, `nextcloud`, `immich`, and `authentik` need planned downtime or a
data migration path.

## Per-App Notes

### Homepage

- Low risk.
- Push after the target namespace exists.
- Verify the Deployment, Service, and HTTPRoute in `app-homepage`.

### Docmost

- Requires downtime for a clean filesystem and database cutover.
- Existing Longhorn PVCs and CNPG resources in `apps` will not move automatically.
- VolSync configuration now expects the repository PVC in `app-docmost`.

Recommended sequence:

1. Stop writes to Docmost.
2. Confirm the latest CNPG backup and VolSync snapshot.
3. Migrate or restore the data into `app-docmost`.
4. Sync the Docmost application.
5. Verify HTTP, database connectivity, and storage contents.

### Nextcloud

- Requires downtime.
- Existing Longhorn PVCs, CNPG resources, and Redis-backed app state stay in `apps`
  until explicitly migrated.
- VolSync configuration now expects the repository PVC in `app-nextcloud`.

Recommended sequence:

1. Put Nextcloud into maintenance mode or otherwise stop writes.
2. Confirm the latest CNPG backup and filesystem backup.
3. Migrate or restore the data into `app-nextcloud`.
4. Sync the Nextcloud application.
5. Verify login, file access, and background jobs.

### Immich

- Requires downtime.
- `immich-media` is a namespace-scoped PVC bound to a fixed PV. The claim must be
  recreated in `app-immich` in a controlled cutover.
- CNPG resources also need a namespace-aware restore or migration path.

Recommended sequence:

1. Stop Immich writes and background jobs.
2. Confirm media availability and the latest database backup.
3. Rebind or recreate the media claim in `app-immich`.
4. Restore or migrate the database into `app-immich`.
5. Sync the Immich application and verify API, web, and ML paths.

### Authentik

- Treat this like other stateful infra services, not like a stateless Helm move.
- The database PVC and media PVC remain namespace-bound.

Recommended sequence:

1. Schedule downtime for dependent SSO flows.
2. Confirm the latest CNPG backup.
3. Migrate or restore data into `authentik`.
4. Sync the Authentik application.
5. Verify login flows for Argo CD and downstream apps.

## Verification

After each app migration, verify:

- Argo CD reports the Application healthy and synced.
- Pods are running only in the target namespace.
- No old Service DNS names are still referenced.
- PVCs are bound in the target namespace.
- Routes and login flows work end to end.

## Cleanup

Only remove legacy resources from `apps` after:

- the replacement app is healthy
- data integrity is confirmed
- rollback is no longer needed
