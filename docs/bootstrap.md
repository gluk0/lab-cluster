# Bootstrapping the cluster


## Create the SOPS age key secret

```sh
age -p -o age.agekey
kubectl create namespace flux-system
kubectl create secret generic sops-age -n flux-system \
  --from-file=age.agekey
```

## 5. Bootstrap Flux

> The committed `clusters/homelab/flux-system/gotk-sync.yaml` points at
> `https://github.com/gluk0/homelab-cluster.git`. If this repo lives at a
> different URL, re-run `flux bootstrap` so the sync manifest matches, or
> update the URL before pushing.

```sh
flux bootstrap github \
  --owner=<github-user> \
  --repository=<repo-name> \
  --branch=main \
  --path=clusters/homelab \
  --personal
```

## 6. Watch reconciliation

```sh
flux get kustomizations --watch
```

Expected order: `flux-system` -> `networking` -> `infrastructure` ->
`gateway-api-crds` -> `configs` -> `cloudflare-gateway-controller` -> `apps`.

## 7. Post-bootstrap verification

```sh
kubectl get nodes -o wide                     # all Ready
kubectl -n kube-system get pods -l k8s-app=cilium   # Running on every node
cilium status                                 # if cilium-cli is installed
kubectl -n istio-system get svc               # ilb gateway got a MetalLB IP
flux get helmreleases -A                      # all Ready, including cilium
```

Then confirm the apps respond through the Cloudflare tunnel
(`gluk0.sh`, `nightscout.gluk0.sh`).

## Upgrading Cilium

Bump `spec.chart.spec.version` in
`infrastructure/networking/cilium/helmrelease.yaml`, commit, and let Flux
roll it out. Pin exact versions — the CNI is not the place for auto-upgrades.
