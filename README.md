# Falco Labs

## Setup

```bash
make up

kubectl run -it curl-test --image=alpine -- sh
kubectl exec -it $(kubectl get pods -l app=nginx -o name) -- cat /etc/shadow


make logs # to see falco logs and events


make down # tear down lab
```
