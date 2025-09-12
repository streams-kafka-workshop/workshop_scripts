#!/usr/bin/env bash
set -euo pipefail

IMAGE=registry.redhat.io/amq-streams/kafka-40-rhel9:3.0.0
BOOTSTRAP=kafka-kafka-bootstrap:9092
TOPIC=demo
GROUP=demo-cg

echo "[cleanup] deleting any old consumers..."
oc delete pod cg-c1 cg-c2 cg-c3 --ignore-not-found >/dev/null 2>&1 || true

echo "[1/3] starting the first consumer cg-c1..."
oc run cg-c1 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --from-beginning \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
# wait until the pod is Ready (container running)
oc wait pod/cg-c1 --for=condition=Ready --timeout=120s

read -r -p $'[input] Press Enter to start the second consumer cg-c2...' _

echo "[2/3] starting consumer cg-c2 in the same group ..."
oc run cg-c2 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
oc wait pod/cg-c2 --for=condition=Ready --timeout=120s

read -r -p $'[input] Press Enter to start the third consumer cg-c3...' _

echo "[3/3] starting consumer cg-c3 in the same group..."
oc run cg-c3 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
oc wait pod/cg-c3 --for=condition=Ready --timeout=120s

echo
echo "✅ All three consumers are running and consuming messages"
echo
read -r -p $'[input] Press Enter to STOP all consumers...' _
oc delete pod cg-c1 cg-c2 cg-c3 --now --ignore-not-found
echo "🛑 Stopped."
