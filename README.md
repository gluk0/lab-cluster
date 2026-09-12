# lab-cluster

FluxCD repository for the `lab` homelab cluster, running on Talos Linux with
Flannel as the CNI.

## Layout

```text
clusters/homelab/     Flux entry point (flux-system + one Kustomization per layer)
infrastructure/
  networking/         Flannel CNI (vendored, pinned)
  sources/            HelmRepository / GitRepository definitions
  controllers/        Operators and controllers (cert-manager, MetalLB, Istio, ...)
  configs/            CR instances that need the controllers' CRDs
apps/                 Workloads (nightscout, website)
docs/                 Bootstrap and operations documentation
scripts/              validate.sh - local kustomize build checks
```

## Reconciliation order

```text
flux-system
  -> networking                      (Flannel CNI)
  -> infrastructure                  (sources + controllers)
  -> gateway-api-crds                (Gateway API standard CRDs)
  -> configs                         (issuers, pools, gateways)
  -> cloudflare-gateway-controller   (Cloudflare tunnel gateway)
  -> apps                            (nightscout, website)
```

Each stage `dependsOn` the previous one, so CRDs always exist before the CRs
that use them.

## Networking

- **CNI**: Flannel, vendored and pinned in
  `infrastructure/networking/flannel/`. The pod network `10.244.0.0/16` must
  match `cluster.network.podSubnets` in the Talos machine config.
- **Ingress path**: Cloudflare tunnel Gateway (`HTTPRoute`) -> Istio
  `istio-ilb-gateway` -> per-app Istio `Gateway`/`VirtualService` -> Service.
- **NetworkPolicy**: Flannel does *not* enforce NetworkPolicy. The policies in
  this repo document intent and become effective only if a policy engine
  (e.g. Calico in policy-only mode) is added.

## Getting started

See [docs/bootstrap.md](./docs/bootstrap.md) for provisioning Talos and
bootstrapping Flux, and [docs/secrets.md](./docs/secrets.md) for the SOPS
secrets workflow.

## Validation

```sh
./scripts/validate.sh          # kustomize-builds every layer locally
flux check                     # with cluster access
flux get kustomizations        # watch reconciliation state
```

## Adding an app

1. Create `apps/<name>/` with a `kustomization.yaml`, `namespace.yaml` and
   the workload manifests (or a `HelmRelease` + source).
2. Expose it by adding an Istio `Gateway`/`VirtualService` and an `HTTPRoute`
   attached to `homelab-gateway` in the `cloudflare-gateway` namespace.
3. Add the directory to `apps/kustomization.yaml`.
4. Put secrets in a SOPS-encrypted Secret (see `docs/secrets.md`).
5. Run `./scripts/validate.sh`, commit, and let Flux reconcile.

