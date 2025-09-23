#!/usr/bin/env bash
set -euo pipefail

prompt() { read -r -p "$1" _ < /dev/tty; }

IMAGE=registry.redhat.io/amq-streams/kafka-40-rhel9:3.0.0
BOOTSTRAP=kafka-kafka-bootstrap:9092
TOPIC=demo
GROUP=demo-cg

echo "[cleanup] deleting any old consumers..."
oc delete pod cg-c1 cg-c2 cg-c3 cg-c4 --ignore-not-found >/dev/null 2>&1 || true

echo "[1/4] starting the first consumer cg-c1..."
oc run cg-c1 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --from-beginning \
    --consumer-property client.id=\$HOSTNAME \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
# wait until the pod is Ready (container running)
oc wait pod/cg-c1 --for=condition=Ready --timeout=120s

prompt $'[input] Press Enter to start the second consumer cg-c2...'

echo "[2/4] starting consumer cg-c2 in the same group ..."
oc run cg-c2 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --consumer-property client.id=\$HOSTNAME \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
oc wait pod/cg-c2 --for=condition=Ready --timeout=120s

prompt $'[input] Press Enter to start the third consumer cg-c3...'

echo "[3/4] starting consumer cg-c3 in the same group..."
oc run cg-c3 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --consumer-property client.id=\$HOSTNAME \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
oc wait pod/cg-c3 --for=condition=Ready --timeout=120s

echo
echo "✅ All three consumers are running and have been assigned partitions"

prompt $'[input] Press Enter to start the fourth consumer cg-c4...'

echo "[4/4] starting consumer cg-c4 in the same group..."
oc run cg-c4 --restart=Never \
  --image="$IMAGE" -- \
  bash -lc "/opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP \
    --topic $TOPIC \
    --group $GROUP \
    --consumer-property client.id=\$HOSTNAME \
    --property print.key=true \
    --property print.partition=true \
    --property key.separator=' | '"
oc wait pod/cg-c4 --for=condition=Ready --timeout=120s

echo
echo "✅ Consumer 4 is running and but is currently idle"
echo
prompt $'[input] Press Enter to STOP all consumers except cg-c1...'
oc delete pod cg-c2 cg-c3 cg-c4 --now --ignore-not-found
echo "🛑 Stopped cg-c2, cg-c3, cg-c4. cg-c1 remains running."

prompt $'[input] Press Enter to STOP the remaining consumer cg-c1...'
oc delete pod cg-c1 --now --ignore-not-found
echo "🛑 All consumers stopped."
