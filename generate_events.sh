#!/bin/bash
set -e

## vars
POD=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')

echo "[+] Generating event: reading /etc/shadow..."
kubectl exec -it "$POD" -- cat /etc/shadow || echo "[!] Failed to read /etc/shadow"

echo "[+] Generating event: writing to /etc/testfile..."
kubectl exec -it "$POD" -- sh -c "echo 'Falco Test' > /etc/testfile" || echo "[!] Write event failed"

echo "[+] Generating event: spawning a shell..."
kubectl exec -it "$POD" -- sh -c "sh -c 'echo Shell spawned'" || echo "[!] Shell spawn event failed"

echo "[+] Event generation complete."
