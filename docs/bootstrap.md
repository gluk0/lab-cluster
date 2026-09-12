# Bootstrapping the cluster

Fresh-cluster procedure: Talos first, then networking, then Flux.

## 1. Talos machine config

The relevant sections of the machine config:

```yaml
cluster:
  network:
    cni:
      name: none          # Flux/Git owns the CNI (this repo vendors Flannel)
    podSubnets:
      - 10.244.0.0/16     # must match the Network CIDR in kube-flannel.yml
    serviceSubnets:
      - 10.96.0.0/12
```

Alternatively, set `cni.name: flannel` to let Talos bootstrap its bundled
Flannel; the vendored manifest in this repo will then be adopted by Flux
via server-side apply. `cni.name: none` keeps a single source of truth in
Git but requires step 3 below before Flux can run.

Apply and bootstrap:

```sh
talosctl apply-config --insecure -n <node-ip> --file controlplane.yaml
talosctl bootstrap -n <node-ip>
talosctl kubeconfig -n <node-ip>
```

## 2. Verify the API server

```sh
kubectl get nodes        # nodes appear (NotReady until a CNI is running)
```

## 3. Install the CNI (only if `cni.name: none`)

Flux pods cannot start without a pod network, so apply the vendored Flannel
manifest once by hand. Flux adopts and manages it from then on:

```sh
kubectl apply -f infrastructure/networking/flannel/kube-flannel.yml
kubectl -n kube-flannel get pods -w      # wait for Running
kubectl get nodes                        # nodes become Ready
```

## 4. Create the SOPS age key secret

Required before the `apps` layer can decrypt secrets — see
[secrets.md](./secrets.md):

```sh
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
kubectl -n kube-flannel get pods              # Running on every node
kubectl -n istio-system get svc               # ilb gateway got a MetalLB IP
flux get helmreleases -A                      # all Ready
```

Then confirm the apps respond through the Cloudflare tunnel
(`gluk0.sh`, `nightscout.gluk0.sh`).

## Upgrading Flannel

```sh
cd infrastructure/networking/flannel
curl -sSL -o kube-flannel.yml \
  https://github.com/flannel-io/flannel/releases/download/<version>/kube-flannel.yml
git diff        # review, then commit
```
