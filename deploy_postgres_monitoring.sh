#!/bin/bash

# Set namespaces
POSTGRES_NAMESPACE="project-plato"
PROM_NAMESPACE="monitoring"

# Set PostgreSQL credentials
POSTGRES_PASSWORD="SuperSecret123"

# Add Helm Repositories
echo "Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespaces if they don't exist
echo "Ensuring namespaces exist..."
kubectl create namespace $POSTGRES_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $PROM_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL with metrics enabled
echo "Deploying PostgreSQL with metrics enabled..."
helm install postgres bitnami/postgresql \
  --namespace $POSTGRES_NAMESPACE \
  --set primary.persistence.enabled=false \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  --set global.postgresql.auth.postgresPassword="$POSTGRES_PASSWORD"

# Deploy kube-prometheus-stack
echo "Deploying kube-prometheus-stack..."
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace $PROM_NAMESPACE \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Wait for PostgreSQL and Prometheus to be ready
echo "Waiting for PostgreSQL to be ready..."
kubectl rollout status deployment -n $POSTGRES_NAMESPACE postgres-postgresql

echo "Waiting for Prometheus to be ready..."
kubectl rollout status deployment -n $PROM_NAMESPACE monitoring-kube-prometheus-stack-prometheus

# Port forward Prometheus (optional)
echo "Access Prometheus UI at: http://localhost:9090"
kubectl port-forward -n $PROM_NAMESPACE svc/monitoring-prometheus 9090 &

# Port forward Grafana (optional)
echo "Access Grafana UI at: http://localhost:3000"
kubectl port-forward -n $PROM_NAMESPACE svc/monitoring-grafana 3000 &

# Wait for Grafana pod to be ready
echo "Waiting for Grafana to be ready..."
kubectl rollout status deployment -n $PROM_NAMESPACE monitoring-grafana

# Retrieve Grafana admin password
echo "Retrieving Grafana admin password..."
GRAFANA_PASSWORD=$(kubectl get secret -n $PROM_NAMESPACE monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Grafana Admin Password: $GRAFANA_PASSWORD"

# Instructions for verifying PostgreSQL metrics in Prometheus
echo "PostgreSQL Metrics Verification:"
echo "1. Open Prometheus UI: http://localhost:9090"
echo "2. Search for PostgreSQL metrics like:"
echo "   - pg_up"
echo "   - pg_stat_activity_count"
echo "   - pg_database_size_bytes"
echo ""
echo "Grafana Access:"
echo "1. Open Grafana UI: http://localhost:3000"
echo "2. Login with:"
echo "   - Username: admin"
echo "   - Password: $GRAFANA_PASSWORD"
echo ""
echo "PostgreSQL is now monitored by Prometheus & Grafana!"

# How to Run the Script
chmod +x deploy_postgres_monitoring.sh
./deploy_postgres_monitoring.sh
