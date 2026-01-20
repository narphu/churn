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
	kind create cluster --name $(K8S_CLUSTER_NAME) --image kindest/node:v1.27.3
	kubectl cluster-info --context kind-mlops-kserve

kind-delete:
	kind delete cluster --name $(K8S_CLUSTER_NAME)


# == Minio Delete ==
minio-deploy: 
	kubectl apply -f kserve/manifests/minio-deploy.yaml

minio-delete:
	kubectl delete -f kserve/manifests/minio-deploy.yaml

minio-port-forward:
	kubectl port-forward svc/minio-service 9000:9000

minio-auth-setup:
	kubectl create secret generic minio-creds \
		--from-literal=AWS_ACCESS_KEY_ID=$(MINIO_ACCESS_KEY) \
		--from-literal=AWS_SECRET_ACCESS_KEY=$(MINIO_SECRET_KEY)
	kubectl patch configmap inferenceservice-config -n kserve \
  		--type merge \
  		-p '{"data": {"storageInitializer": "{\"s3\":{\"secretKeySecretName\":\"minio-creds\"}}"}}'


# == MC bucket and model sync ==

mc-alias:
	mc alias set $(MINIO_ALIAS) $(MINIO_HOST) $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY)

mc-make-bucket:
	mc mb --ignore-existing $(MINIO_ALIAS)/$(MINIO_BUCKET)

mc-upload-model:
	mc cp --recursive $(MODEL_PATH) $(MINIO_ALIAS)/$(MINIO_BUCKET)/sklearn-model

minio-sync-model: mc-alias mc-make-bucket mc-upload-model

# == kserve ==

cert-manager-install: 
	kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.3/cert-manager.yaml
	kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=90s

istio-install:
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 sh -
	cd istio-1.20.3
	export PATH=$PWD/bin:$PATH
	istioctl install --set profile=demo -y

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
