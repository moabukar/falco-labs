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

  echo "[+] Installing Falco (with metrics enabled)..."
  helm install falco falcosecurity/falco \
    --namespace falco \
    -f values.yaml

  echo "[+] Deploying nginx workload..."
  kubectl create deployment nginx --image=nginx

  echo "[+] Installing Prometheus & Grafana..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace

  echo "[+] Waiting for Grafana pod to be Ready..."
  kubectl wait --for=condition=Ready --timeout=180s pods -l app.kubernetes.io/name=grafana -n monitoring

  echo "[+] Creating ConfigMap for Falco Dashboard..."
  kubectl create configmap falco-dashboard \
    --from-file=falco_dashboard.json=falco_dashboard.json \
    -n monitoring || true
  kubectl label configmap falco-dashboard -n monitoring grafana_dashboard=1 --overwrite

  echo "[+] Creating ConfigMap for Grafana datasource..."
  kubectl create configmap grafana-datasource \
    --from-file=datasource.yaml=grafana_datasource.yaml \
    -n monitoring || true
  kubectl label configmap grafana-datasource -n monitoring grafana_datasource=1 --overwrite

  echo "[+] Upgrading kube-prometheus-stack to load dashboard and datasource..."
  helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --reuse-values \
    --set grafana.sidecar.dashboards.enabled=true \
    --set grafana.sidecar.dashboards.label=grafana_dashboard \
    --set grafana.dashboardsConfigMaps.falco-dashboard="falco-dashboard" \
    --set grafana.sidecar.datasources.enabled=true \
    --set grafana.sidecar.datasources.label=grafana_datasource

  echo "[+] Forwarding Grafana service on port 3000..."
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
  
  echo "[+] Waiting for Falco pods to be Ready..."
  kubectl wait --for=condition=Ready --timeout=180s pods -l app.kubernetes.io/name=falco -n falco

  echo "[+] Lab setup complete."
  echo "[+] Grafana is available at http://localhost:3000"
  echo "[+] To get the Grafana admin password, run:"
  echo "    kubectl -n monitoring get secrets kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
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

# Manual test examples:
# kubectl run -it curl-test --image=alpine -- sh
# apk add curl
# curl http://example.com
