# whispers-k8s

Helm charts for running the `whispers` backend, webapp, and `coturn` on a small Minikube server with public internet access.

## What is included

- `whispers`: backend chart for the Java server, exposed internally on port `8080`.
- `whispers-webapp`: frontend chart with optional ingress, ConfigMap-backed public config, and Secret-backed env vars.
- `coturn`: TURN/STUN chart with public-internet-oriented defaults and support for reading TURN credentials from a Kubernetes Secret.
- `scripts/install-minikube-mvp.sh`: installs `ingress-nginx` and deploys all three charts.
- `examples/*.yaml`: starter public-internet values files.

## MVP assumptions

- Minikube runs on a server with a stable public IP.
- DNS for your web domain points at that server.
- TLS for the webapp is provided by a manually created Kubernetes TLS secret.
- `ingress-nginx` is installed in host-network mode so it binds directly on the server for ports `80/443`.
- TURN relay traffic is exposed from the node, so you must open the TURN listen port and the relay UDP range on your firewall.
- TURN auth in this MVP uses a static username/password pair, which is simpler but weaker than backend-generated temporary credentials.

## Deploy

1. Create the target namespace and web TLS secret:

```bash
kubectl create namespace whispers
kubectl -n whispers create secret tls whispers-webapp-tls \
  --cert=/path/to/fullchain.pem \
  --key=/path/to/privkey.pem
```

2. Create the TURN auth secret that `coturn` will read at runtime:

```bash
kubectl -n whispers create secret generic coturn-auth \
  --from-literal=username=turnuser \
  --from-literal=password='replace-with-strong-password'
```

3. Copy and adjust the example values files:

```bash
cp examples/whispers-backend-values.yaml values-backend.yaml
cp examples/whispers-webapp-public-values.yaml values-webapp.yaml
cp examples/coturn-public-values.yaml values-coturn.yaml
```

4. Install ingress and all three charts:

```bash
API_VALUES=values-backend.yaml WEB_VALUES=values-webapp.yaml TURN_VALUES=values-coturn.yaml ./scripts/install-minikube-mvp.sh
```

## Firewall / routing

Allow these inbound ports to the server:

- TCP 80
- TCP 443
- TCP 3478
- UDP 3478
- UDP relay range used by `coturn` such as `49160-49200`

If you keep `hostNetwork: true` for `coturn`, the relay range is opened on the node itself, which is the simplest workable setup for a one-node Minikube server.

## Notes

- The frontend chart now uses `service.port` and `service.targetPort`.
- The backend chart assumes the Java container listens on `PORT` and defaults to `8080`, matching the provided Dockerfile.
- `coturn` requires `turn.publicAddress` plus either `turn.auth.existingSecret.name` or direct fallback values in `turn.auth.username` and `turn.auth.password`.
- The expected keys in the Kubernetes Secret are `username` and `password` unless you override them in the chart values.
- If you want to supply a full custom `turnserver.conf`, set `secret.create=true` and provide `secret.turnserverConf`.
- If your backend or frontend image is local-only, build it into the Minikube runtime before installing the chart.
