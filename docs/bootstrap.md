```sh
age -p -o age.agekey
kubectl create namespace flux-system
kubectl create secret generic sops-age -n flux-system \
  --from-file=age.agekey

```sh
flux bootstrap github \
  --owner=gluk0 \
  --repository=lab-cluster \
  --branch=main \
  --path=clusters/homelab \
  --personal
```

