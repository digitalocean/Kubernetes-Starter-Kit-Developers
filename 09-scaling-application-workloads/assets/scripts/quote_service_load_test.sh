#!/usr/bin/env sh

echo
echo "[INFO] Starting load testing in 10s..."
sleep 10
echo "[INFO] Working (press Ctrl+C to stop)..."
kubectl run -i --tty load-generator \
    --rm \
    --image=busybox \
    --restart=Never \
    -n hpa-external-load \
    -- /bin/sh -c "while sleep 0.001; do wget -q -O- http://quote; done" > /dev/null 2>&1
echo "[INFO] Load testing finished."
