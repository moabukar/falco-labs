# Falco Labs

## Setup

```bash
# setup lab
make up

# test curl in container & write to /etc (this will be detected by falco)
kubectl run -it curl-test --image=alpine -- sh
kubectl exec -it $(kubectl get pods -l app=nginx -o name) -- cat /etc/shadow

# see falco logs and events
make logs # to see falco logs and events


## Access Prometheus & Grafana

### Prometheus

kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
## http://prometheus.localhost:9090

### Grafana

## http://grafana.localhost:3000
## user: admin
## password: prom-operator
helm upgrade falco falcosecurity/falco --namespace falco -f values.yaml


make down # tear down lab
```
