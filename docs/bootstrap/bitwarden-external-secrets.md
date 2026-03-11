# Bitwarden Secrets Manager Bootstrap

This repo installs External Secrets Operator from the official Helm chart via an
Argo CD `Application` and uses an `ExternalSecret` to create the `cloudflared`
secret in `cloudflare-system`.

## Manual bootstrap secrets

Create the Bitwarden machine-account access token secret:

```sh
kubectl -n external-secrets create secret generic bitwarden-access-token \
  --from-literal=token='XX_REPLACE_ME__WITH_ACTUAL_SECRET_XX' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Create the Bitwarden SDK server TLS secret:

```sh
kubectl -n external-secrets create secret generic bitwarden-tls-certs \
  --from-file=tls.crt=bitwarden-sdk-server.crt \
  --from-file=tls.key=bitwarden-sdk-server.key \
  --from-file=ca.crt=bitwarden-sdk-server-ca.crt
```

For a self-signed setup, `bitwarden-sdk-server-ca.crt` can be the same certificate
file as `bitwarden-sdk-server.crt`.

These bootstrap secrets are intentionally not committed to Git.

## Required Bitwarden setup

Use Bitwarden Secrets Manager, not the normal Bitwarden vault.

- A Bitwarden machine-account token with access to the configured project
- A TLS certificate for `bitwarden-sdk-server.external-secrets.svc.cluster.local`
- A Bitwarden Secrets Manager secret named `cloudflare-tunnel-token` with the Cloudflare tunnel token as its value

## How To Add More Secrets

Add or change secrets in Bitwarden Secrets Manager here:

`https://vault.bitwarden.eu/#/sm/00e4c26a-2e61-4ca9-8ead-b40900e7e081/projects/f2215b03-7218-473e-a29f-b40901159f28/secrets`

Update the machine-account token in-cluster when needed:

```sh
kubectl -n external-secrets create secret generic bitwarden-access-token \
  --from-literal=token='XX_REPLACE_ME__WITH_ACTUAL_SECRET_XX' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then point an `ExternalSecret` at the Bitwarden secret key you created. For example:

```yaml
spec:
  data:
    - secretKey: example-key
      remoteRef:
        key: example-secret-name-in-bitwarden
```

## Flow

1. Argo CD syncs `kubernetes/infra`.
2. The `external-secrets` child app installs ESO and the Bitwarden SDK server from Helm.
3. The `ClusterSecretStore` connects to Bitwarden Secrets Manager through the SDK server.
4. The `cloudflared` `ExternalSecret` reads `cloudflare-tunnel-token` from Bitwarden Secrets Manager.
5. External Secrets Operator creates the Kubernetes `Secret/cloudflared`.
6. The existing cloudflared Deployment consumes `tunnel-token` from that generated secret.
