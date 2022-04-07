#!/usr/bin/env sh

echo
echo "[INFO] Starting load testing in 10s..."
sleep 10
echo "[INFO] Working (press Ctrl+C to stop)..."
kubectl run -i --tty load-generator \
    --rm \
    --image=busybox \
    --restart=Never \
    -n prometheus-custom-metrics-test \
    -- /bin/sh -c "while sleep 0.2; do wget -q -O- http://prometheus-example-app:8080; done" > /dev/null 2>&1
echo "[INFO] Load testing finished."
sleep 1000000
