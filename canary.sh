#!/bin/bash

NAMESPACE= Enter NameSpace Deployment
CANARY_DEPLOYMENT=canary-app
# get Pod current
CURRENT_REPLICAS=$(kubectl get deployment $CANARY_DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
echo "pod deployment $CURRENT_REPLICAS replicas."

while true; do
  read -p "Do you want scale pod canary? (y/n): " yn
  case $yn in
    [Yy]* )
      NEW_REPLICAS=$((CURRENT_REPLICAS + 1))
      kubectl scale deployment $CANARY_DEPLOYMENT --replicas=$NEW_REPLICAS -n $NAMESPACE
      echo "Complate Scale $NEW_REPLICAS replicas."
      CURRENT_REPLICAS=$NEW_REPLICAS
      ;;
    [Nn]* )
      echo "Stop release new version."
      exit
      ;;
    * ) echo "Plz enter y or n.";;
  esac
done
