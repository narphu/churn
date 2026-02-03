# === Config ===
PYTHON=python3
ML_DIR=ml

ML_VENV=$(ML_DIR)/venv
DATA_FILE=data

MLFLOW_DIR=$(PWD)/mlflow
MLFLOW_IMAGE=mlflow-tracker:latest
MLFLOW_CONTAINER=mlflow-server
MLFLOW_PORT=5000
MLFLOW_DATA=$(PWD)/mlflow


# === MinIO Setup ===

MINIO_ALIAS=minio
MINIO_HOST=http://localhost:9000
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=churn123
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=churn123
MINIO_BUCKET=mlflow
MODEL_PATH=models/randomforest


# === Setup Environment ===
ml-venv:
	@echo "Creating ML virtual environment..."
	$(PYTHON) -m venv $(ML_VENV)
	@echo "✅ ML venv created at $(ML_VENV)"

ml-install: ml-venv
	@echo "Installing requirements..."
	. $(ML_VENV)/bin/activate && pip install --upgrade pip && pip install -r $(ML_DIR)/requirements.txt


# === PreProcess ===
preprocess: ml-install
	@echo "Pre processing model data..."
	. $(ML_VENV)/bin/activate && PYTHONPATH=$(ML_DIR) python $(ML_DIR)/preprocess.py

# === Training ===
train: ml-install
	@echo "Training churn model..."
	. $(ML_VENV)/bin/activate && PYTHONPATH=$(ML_DIR) python $(ML_DIR)/train.py

# === Promote ===
promote:
	. $(ML_VENV)/bin/activate && PYTHONPATH=$(ML_VENV) python $(ML_DIR)/evaluate_and_promote.py

# === RUN MLflow UI (Docker) ===
mlflow-ui: mlflow-up
	@echo  "MLflow UI available at http://localhost:5000"

.PHONY: mlflow-build mlflow-up mlflow-down mlflow-logs mlflow-uri

mlflow-build:
	docker build -t $(MLFLOW_IMAGE) mlflow

mlflow-up: mlflow-build
	docker run -d \
		--name $(MLFLOW_CONTAINER) \
		-p $(MLFLOW_PORT):5000 \
		-v $(MLFLOW_DIR):/mlflow \
		$(MLFLOW_IMAGE)

mlflow-down:
	docker stop $(MLFLOW_CONTAINER) || true
	docker rm $(MLFLOW_CONTAINER) || true

mlflow-logs:
	docker logs -f $(MLFLOW_CONTAINER)


# === Fast API === 
serve-api:
	docker build -t churn-api ./api
	docker run --rm -p 8000:8000 --add-host=host.docker.internal:host-gateway --name churn-api churn-api

# === Docker compose ===
docker-compose-up:
	docker-compose up --build


# === Kind + KServe Setup ===
K8S_CLUSTER_NAME=mlops-kserve

kind-create:
	@if kind get clusters | grep -q "^$(K8S_CLUSTER_NAME)$$"; then \
		echo "Kind cluster $(K8S_CLUSTER_NAME) already exists; skipping create."; \
	else \
		kind create cluster --name $(K8S_CLUSTER_NAME) --image kindest/node:v1.27.3; \
	fi
	kubectl cluster-info --context kind-$(K8S_CLUSTER_NAME)
kind-delete:
	kind delete cluster --name $(K8S_CLUSTER_NAME)


# == Minio Delete ==
minio-deploy: 
	kubectl apply -f kserve/manifests/minio-deploy.yaml

minio-delete:
	kubectl delete -f kserve/manifests/minio-deploy.yaml

minio-port-forward:
	kubectl port-forward svc/minio-service 9000:9000

minio-port-forward-start:
	@nohup kubectl port-forward svc/minio-service 9000:9000 > /tmp/minio-port-forward.log 2>&1 &

minio-auth-setup:
	kubectl create secret generic minio-creds \
		--from-literal=AWS_ACCESS_KEY_ID=$(MINIO_ACCESS_KEY) \
		--from-literal=AWS_SECRET_ACCESS_KEY=$(MINIO_SECRET_KEY) \
		--from-literal=AWS_ENDPOINT_URL=http://minio-service.default.svc.cluster.local:9000 \
		--from-literal=AWS_DEFAULT_REGION=us-east-1 \
		-n default \
		--dry-run=client -o yaml | kubectl apply -f -
	kubectl patch configmap inferenceservice-config -n kserve \
  		--type merge \
  		-p '{"data": {"credentials": "{\n  \"storageSpecSecretName\": \"storage-config\",\n  \"storageSecretNameAnnotation\": \"serving.kserve.io/storageSecretName\",\n  \"gcs\": {\n    \"gcsCredentialFileName\": \"gcloud-application-credentials.json\"\n  },\n  \"s3\": {\n    \"s3AccessKeyIDName\": \"AWS_ACCESS_KEY_ID\",\n    \"s3SecretAccessKeyName\": \"AWS_SECRET_ACCESS_KEY\",\n    \"s3Endpoint\": \"minio-service.default.svc.cluster.local:9000\",\n    \"s3UseHttps\": \"0\",\n    \"s3Region\": \"us-east-1\",\n    \"s3VerifySSL\": \"0\",\n    \"s3UseVirtualBucket\": \"0\",\n    \"s3UseAnonymousCredential\": \"0\",\n    \"s3CABundle\": \"\"\n  }\n}"}}'


# == MC bucket and model sync ==

mc-alias:
	mc alias set $(MINIO_ALIAS) $(MINIO_HOST) $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY)

mc-make-bucket:
	mc mb --ignore-existing $(MINIO_ALIAS)/$(MINIO_BUCKET)

mc-upload-model:
	mc cp --recursive $(MODEL_PATH) $(MINIO_ALIAS)/$(MINIO_BUCKET)/sklearn-model

model-prepare:
	test -f $(MODEL_PATH)/model.joblib || cp $(MODEL_PATH)/churn_model.joblib $(MODEL_PATH)/model.joblib

minio-clean-model:
	mc rm --force $(MINIO_ALIAS)/$(MINIO_BUCKET)/sklearn-model/randomforest/churn_model.joblib || true

minio-sync-model: minio-port-forward-start model-prepare mc-alias mc-make-bucket minio-clean-model mc-upload-model

# == kserve ==

cert-manager-install: 
	kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.3/cert-manager.yaml
	kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=90s

istio-install:
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 sh -
	./istio-1.20.3/bin/istioctl install --set profile=demo -y

# Install Knative (CRDs + Core)
knative-install:
	kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.11.2/serving-crds.yaml
	kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.11.2/serving-core.yaml
	kubectl apply -f https://github.com/knative/net-kourier/releases/download/knative-v1.11.2/kourier.yaml
	kubectl patch configmap/config-network -n knative-serving --type merge -p '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'


kserve-install: cert-manager-install
	kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.11.0/kserve.yaml
	kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.9.0/kserve-runtimes.yaml
	kubectl wait --for=condition=Available deployment --all -n kserve --timeout=120s

kserve-deploy:
	kubectl apply -f kserve/manifests/local-pvc.yaml
	kubectl apply -f kserve/manifests/kserve-inference.yaml

kserve-delete:
	kubectl delete -f kserve/manifests/kserve-inference.yaml
	kubectl delete -f kserve/manifests/local-pvc.yaml
	kubectl delete -f https://github.com/kserve/kserve/releases/download/v0.11.0/kserve.yaml

kserve-clean:
	kubectl delete service minio-service || true
	kubectl delete deployment minio || true
	kubectl delete inferenceservice churn-rf || true
	kubectl delete -f https://github.com/kserve/kserve/releases/download/v0.11.0/kserve.yaml

# === Clean ===
clean: kserve-clean kserve-local-delete minio-delete kind-delete
	rm -rf $(ML_VENV) __pycache__ */__pycache__

# === KServe Quickstart ===
kserve-up: kind-create istio-install knative-install kserve-install minio-deploy minio-auth-setup minio-sync-model kserve-deploy

kserve-predict:
	@set -e; \
	kubectl wait --for=condition=Ready pod -n default -l serving.kserve.io/inferenceservice=churn-rf --timeout=180s; \
	POD=$$(kubectl get pods -n default -l serving.kserve.io/inferenceservice=churn-rf -o jsonpath='{.items[0].metadata.name}'); \
	if [ -z "$$POD" ]; then echo "No churn-rf pod found"; exit 1; fi; \
	kubectl port-forward -n default pod/$$POD 8083:8080 > /tmp/churn-rf-port-forward.log 2>&1 & \
	PF_PID=$$!; \
	sleep 3; \
	curl -sS http://localhost:8083/v1/models/churn-rf:predict \
		-H "Content-Type: application/json" \
		-d '{"instances": [[114.74, 114.74, 1.0, 1.0]]}'; \
	echo; \
	kill $$PF_PID

kserve-down: kserve-clean minio-delete kind-delete
