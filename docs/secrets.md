# Secrets management (SOPS + age)

No plaintext secrets are committed to this repo. Kubernetes Secrets are
encrypted with [SOPS](https://github.com/getsops/sops) using an
[age](https://github.com/FiloSottile/age) key, and decrypted in-cluster by
Flux's kustomize-controller (`decryption.provider: sops` on the `apps`
Kustomization).

## One-time setup

```sh
age-keygen -o age.agekey            # NEVER commit this file
```

1. Put the printed public key (`age1...`) into `.sops.yaml` at the repo root.
2. Create the in-cluster decryption secret:

```sh
kubectl create secret generic sops-age -n flux-system \
  --from-file=age.agekey
```

Keep `age.agekey` in a password manager — it is the only way to decrypt the
repo's secrets.

## Adding a secret

Example for nightscout (template at
`apps/nightscout/secret-values.example.yaml`):

```sh
cp apps/nightscout/secret-values.example.yaml apps/nightscout/secret-values.yaml
# edit the real values
sops --encrypt --in-place apps/nightscout/secret-values.yaml
```

Add the file to `apps/nightscout/kustomization.yaml`:

```yaml
resources:
  - secret-values.yaml
```

Commit. Only `data`/`stringData` fields are encrypted, so diffs stay
reviewable.

## How nightscout consumes it

`apps/nightscout/helmrelease.yaml` merges the secret as Helm values:

```yaml
valuesFrom:
  - kind: Secret
    name: nightscout-secret-values
    valuesKey: values.yaml
```

The MongoDB password lives only in the encrypted secret, not in the
HelmRelease.

## Docker Hub pull secret (optional)

Nightscout's values reference `dockerhub-pull-secret` to avoid Docker Hub
rate limits. Images are public, so this is optional — a missing pull secret
only produces a kubelet warning. To create it (SOPS-encrypted like above):

```sh
kubectl create secret docker-registry dockerhub-pull-secret -n nightscout \
  --docker-username=<user> --docker-password=<token> --dry-run=client -o yaml \
  > apps/nightscout/dockerhub-pull-secret.yaml
sops --encrypt --in-place apps/nightscout/dockerhub-pull-secret.yaml
```
