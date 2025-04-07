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

  echo "[+] Installing Prometheus & Grafana..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace

  echo "[+] Forwarding Grafana service on port 3000..."
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
  
  echo "[+] Lab setup complete."
  echo "[+] To generate events, run: ./generate_events.sh"
  echo "[+] Tailing Falco logs..."
  kubectl logs -n falco -l app.kubernetes.io/name=falco -f

elif [ "$1" == "logs" ]; then
  echo "[+] Tailing Falco logs..."
  kubectl logs -n falco -l app.kubernetes.io/name=falco -f

elif [ "$1" == "down" ]; then
  echo "[+] Uninstalling Falco..."
  helm uninstall falco -n falco || true

  echo "[+] Uninstalling Prometheus & Grafana..."
  helm uninstall kube-prometheus-stack -n monitoring || true

  echo "[+] Deleting all kind clusters..."
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
