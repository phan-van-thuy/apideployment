#!/bin/bash
NAMESPACE=
CANARY_DEPLOYMENT=
STABLE_DEPLOYMENT=
TOTAL_PODS=$(kubectl get deployment $STABLE_DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
 
if [ -z "$TOTAL_PODS" ] || [ "$TOTAL_PODS" -eq 0 ]; then
  echo "❌ Do not release deployment stable. Plz check deployment config."
  exit 1
fi
 
CANARY_STEPS=(
  $(( TOTAL_PODS * 10 / 100 ))  # 10%
  $(( TOTAL_PODS * 20 / 100 ))  # 20%
  $(( TOTAL_PODS * 50 / 100 ))  # 50%
  $TOTAL_PODS                   # 100%
)
 
for i in "${!CANARY_STEPS[@]}"; do
  if [ "${CANARY_STEPS[$i]}" -lt 1 ]; then
    CANARY_STEPS[$i]=1
  fi
done
echo "===== Canary Progressive Deployment ====="
echo "📊 Current pod (stable): $TOTAL_PODS"
echo "📊 Task rollout (canary): ${CANARY_STEPS[*]}"
CURRENT_STEP=0
while [ $CURRENT_STEP -lt ${#CANARY_STEPS[@]} ]; do
  TARGET_CANARY=${CANARY_STEPS[$CURRENT_STEP]}
  TARGET_STABLE=$((TOTAL_PODS - TARGET_CANARY))
  echo "🎯 Next step: Canary=$TARGET_CANARY, Stable=$TARGET_STABLE"
  read -p "Proceed rollout to next scale pod? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "➡️ Scaling deployments..."
    kubectl scale deployment $CANARY_DEPLOYMENT --replicas=$TARGET_CANARY -n $NAMESPACE
    kubectl scale deployment $STABLE_DEPLOYMENT --replicas=$TARGET_STABLE -n $NAMESPACE
    echo "⏳ Waiting Canary rollout Complete..."
    if ! kubectl rollout status deployment/$CANARY_DEPLOYMENT -n $NAMESPACE --timeout=120s; then
      echo "❌ Canary rollout Failed!"
      exit 1
    fi

    echo "⏳ Waiting Stable rollout Complete..."
    if ! kubectl rollout status deployment/$STABLE_DEPLOYMENT -n $NAMESPACE --timeout=120s; then
      echo "❌ Stable rollout Failed!"
      exit 1
    fi
 
    echo "✔️ Scale Complete: Canary=$TARGET_CANARY, Stable=$TARGET_STABLE"
    CURRENT_STEP=$((CURRENT_STEP + 1))
  else
    read -p "Do you want to keep the status ?y/n): " keep_confirm
    if [[ "$keep_confirm" =~ ^[Yy]$ ]]; then
      echo "✔️ keep status current."
      exit 0
    else
      echo "↩️ Proceed rollback to initial state..."
      kubectl scale deployment $CANARY_DEPLOYMENT --replicas=0 -n $NAMESPACE
      kubectl scale deployment $STABLE_DEPLOYMENT --replicas=$TOTAL_PODS -n $NAMESPACE
      echo "⏳ Waiting rollback Complete..."
      if ! kubectl rollout status deployment/$STABLE_DEPLOYMENT -n $NAMESPACE --timeout=120s; then
        echo "❌ Rollback Failed!"
        exit 1
      fi
      echo "✔️ Rollback Complete."
      exit 0
    fi
  fi
done

if [ $CURRENT_STEP -eq ${#CANARY_STEPS[@]} ]; then
  echo "🎯 Rollout Complete: Canary complete 100%!"
fi

 
