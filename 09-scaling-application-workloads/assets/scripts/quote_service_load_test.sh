#!/usr/bin/env sh

echo
echo "[INFO] Starting load testing in 10s..."
sleep 5
echo "[INFO] Working..."
kubectl run -i --tty load-generator \
    --rm \
    --image=busybox \
    --restart=Never \
    -n hpa-variable-load \
    -- /bin/sh -c "while sleep 0.001; do wget -q -O- http://quote; done" > /dev/null 2>&1
echo "[INFO] Load testing finished."
