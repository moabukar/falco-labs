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


make down # tear down lab
```
