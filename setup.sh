#!/bin/bash
set -e

function delete_existing_cluster() {
  if kind get clusters | grep -q "^falco-lab$"; then
    echo "[INFO] Cluster 'falco-lab' already exists. Deleting it..."
    kind delete cluster --name falco-lab
  fi
}

if [ "$1" == "up" ]; then
  echo "[+] Creating kind cluster..."
  delete_existing_cluster
  kind create cluster --name falco-lab --config kind.yaml

  echo "[+] Creating namespace 'falco' and deploying custom rules ConfigMap..."
  kubectl create ns falco || true
  kubectl create configmap falco-custom-rules \
    --from-file=custom-rule.yaml=custom-rule.yaml \
    -n falco || true

  echo "[+] Adding Falco Helm repo..."
  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  echo "[+] Installing Falco..."
  helm install falco falcosecurity/falco \
    --namespace falco \
    -f values.yaml

  echo "[+] Deploying nginx deployment..."
  kubectl create deployment nginx --image=nginx

  echo "[+] Falco deployed. Watching logs..."
  kubectl logs -n falco -l app.kubernetes.io/name=falco -f

elif [ "$1" == "logs" ]; then
  echo "[+] Tailing Falco logs..."
  kubectl logs -n falco -l app.kubernetes.io/name=falco -f

elif [ "$1" == "down" ]; then
  echo "[+] Uninstalling Falco..."
  helm uninstall falco -n falco || true

  echo "[+] Deleting all Kind clusters..."
  for cluster in $(kind get clusters); do
    echo "[+] Deleting cluster: $cluster"
    kind delete cluster --name "$cluster"
  done

  echo "[+] Cleanup complete."
else
  echo "Usage: $0 {up|logs|down}"
  exit 1
fi

# Example manual test commands:
# kubectl run -it curl-test --image=alpine -- sh
# apk add curl
# curl http://example.com
