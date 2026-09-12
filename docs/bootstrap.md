# Bootstrapping the cluster

Fresh-cluster procedure: Talos first, then networking, then Flux.

## 1. Talos machine config

Provisioned by Terraform in `lab-infrastructure/talos`. The relevant settings
(see `patches/common.yaml.tftpl`):

```yaml
cluster:
  network:
    cni:
      name: none          # Cilium is installed from this repo
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  proxy:
    disabled: true        # Cilium runs with kubeProxyReplacement
```

Apply and bootstrap (handled by `terraform apply`; manual equivalent):

```sh
talosctl apply-config --insecure -n <node-ip> --file controlplane.yaml
talosctl bootstrap -n <node-ip>
talosctl kubeconfig -n <node-ip>
```

## 2. Verify the API server

```sh
kubectl get nodes        # nodes appear (NotReady until the CNI is running)
```

## 3. Install Cilium once by hand

Flux pods cannot start without a pod network, so install Cilium manually with
the *same release name, namespace, version and values* as
`infrastructure/networking/cilium/helmrelease.yaml`. Flux's helm-controller
then adopts the release and manages it from Git:

```sh
helm repo add cilium https://helm.cilium.io
helm install cilium cilium/cilium \
  --version 1.20.1 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup

kubectl -n kube-system get pods -l k8s-app=cilium -w   # wait for Running
kubectl get nodes                                      # nodes become Ready
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
