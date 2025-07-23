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

# === RUN MLflow UI ===
mlflow-ui: ml-install
	@echo  "Launching MLflow UI at http://localhost:5000 ..."
	. $(ML_VENV)/bin/activate && mlflow ui --backend-store-uri sqlite:///mlflow/mlflow.db

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

cert-manager-install: 
	kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.3/cert-manager.yaml
	kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=90s

kserve-install: cert-manager-install
	kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.11.0/kserve.yaml
	kubectl wait --for=condition=Available deployment --all -n kserve --timeout=120s

kserve-deploy:
	kubectl apply -f kserve/manifests/kserve-inference.yaml

kserve-delete:
	kubectl delete -f kserve/manifests/kserve-inference.yaml

kserve-local-deploy:
	kubectl apply -f kserve/manifests/local-pvc.yaml
	kubectl apply -f kserve/manifests/sklearn-local.yaml

kserve-local-delete:
	kubectl delete -f kserve/manifests/sklearn-local.yaml
	kubectl delete -f kserve/manifests/local-pvc.yaml

# === Clean ===
clean:
	rm -rf $(ML_VENV) __pycache__ */__pycache__
