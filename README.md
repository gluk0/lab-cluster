# lab-cluster

FluxCD repository for the `lab` homelab cluster, running on Talos Linux with
Cilium as the CNI (kube-proxy-less). 

## Networking

- **CNI**: Cilium (`infrastructure/networking/cilium/`), pinned HelmRelease.
  Runs with `kubeProxyReplacement` — the Talos machine config sets
  `cni.name: none` and `proxy.disabled: true`, and Cilium reaches the API
  server via Talos KubePrism (`localhost:7445`).
- **Ingress path**: Cloudflare tunnel Gateway (`HTTPRoute`) -> Istio
  `istio-ilb-gateway` -> per-app Istio `Gateway`/`VirtualService` -> Service.
- **NetworkPolicy**: enforced by Cilium.


## Validation

```sh
./scripts/validate.sh          # kustomize-builds every layer locally
flux check                     # with cluster access
flux get kustomizations        # watch reconciliation state
```
