# Customer Churn Prediction Pipeline (MLOps)

## Overview

This project implements a **robust, production-ready MLOps pipeline** for customer churn prediction. It goes beyond just building a model — the full pipeline supports:

- Data preprocessing  
- Model training with evaluation  
- MLflow for tracking, versioning, and promotion  
- FastAPI-based local inference API  
- KServe deployment for scalable inference on Kubernetes  

It’s designed to mirror real-world AI deployment pipelines — modular, observable, and reproducible.

---

## Why This Project?

Customer churn directly impacts business revenue. Predicting churn helps organizations:

- Intervene proactively with retention strategies  
- Identify risky user segments  
- Understand churn-driving behaviors  

This pipeline demonstrates

- End-to-end MLOps lifecycle  
- Reproducible training and deployment  
- Modern model serving (FastAPI, KServe)  

---

## 🧰 Project Features

| Feature                            | Description                                                                 |
|------------------------------------|-----------------------------------------------------------------------------|
| ✅ Preprocessing                   | Cleans raw data for modeling                                                |
| 🤖 Model Training                  | Trains a baseline Random Forest model                                       |
| 📦 Model Packaging with MLflow     | Logs metrics, artifacts, and models for promotion                           |
| 🚀 Model Registry & Promotion      | Models registered and promoted using MLflow CLI or UI                       |
| ⚡ FastAPI Inference Server        | For local testing and integration tests                                     |
| ☁️ KServe Deployment               | Scalable, production-ready model serving on Kubernetes                      |
| 🔁 CI/CD Ready                     | Includes GitHub Actions workflows for training and deployment               |

---

## 📂 Project Structure

churn-prediction/
│
├── data/ # Raw and cleaned datasets
├── models/ # Trained model artifacts
├── ml/ # Training, preprocessing, promotion
├── mlflow/ # MLflow tracking and registry setup
├── api/ # FastAPI server for local inference
├── kserve/ # KServe YAMLs or InferenceService specs
├── Makefile # Declarative entry points for common tasks
└── README.md


---

## 🔄 Pipeline Flow (MLOps Lifecycle)

         ┌────────────┐
         │  Raw Data  │
         └────┬───────┘
              ▼
     ┌────────────────────┐
     │ Preprocessing      │  ← `ml/preprocess.py`
     └────┬───────────────┘
          ▼
    ┌──────────────────────┐
    │ Model Training │ ← train.py
    │ + Logging to MLflow │
    └────┬─────────────────┘
         ▼
    ┌────────────────────────────┐
    │ MLflow Registry │ ← make promote
    └────┬───────────────────────┘
            ▼
    ┌──────────────────────┐ ┌─────────────────────┐
    │ FastAPI Inference │ ← local │ KServe Deployment │ ← cloud native
    └──────────────────────┘ └─────────────────────┘

---

## 🧪 Key Model Used

- **Random Forest** – Strong baseline with interpretability  

---

## 📦 MLflow Usage

- **Tracking Server**: Dockerized in `mlflow/Dockerfile`  
- **Model Logging**: During `train.py`, each run logs:  
  - Parameters, metrics  
  - `.pkl` model  
- **Promotion**: Use `make promote` to set the production alias when it meets the threshold

---

## 🧪 FastAPI Inference Server

Local inference endpoint:

```bash
make start-api
curl -X POST http://localhost:8000/predict -d '{...input features...}'
```

## ☁️ KServe Deployment
`make deploy-kserve` spins up a model on Kubernetes via KServe

Uses MLflow model URI directly from registry

Includes support for autoscaling, versioning, and canary rollouts

### KServe Quickstart (Kind + MinIO)
Prereqs: Docker Desktop, `kind`, `kubectl`, and MinIO client `mc`.

```bash
make kserve-up
make kserve-predict
```
To tear it down:
```bash
make kserve-down
```

`make kserve-up` creates the cluster, installs Istio/Knative/KServe, deploys MinIO, syncs the model, and applies the InferenceService.

`make kserve-predict` port-forwards the predictor pod and runs a sample inference:
```json
{"instances": [[114.74, 114.74, 1.0, 1.0]]}
```
Feature order: `["total_spent", "avg_order_value", "avg_review_score", "unique_products"]`.

## 🚀 Run the Project
⚙️ 1. Preprocess Data
```bash
make preprocess
```
🎯 2. Train Model
```bash
make train
```
🧾 3. Run MLflow Tracking Server (Docker)
```bash
make mlflow-up
```
📈 4. Promote Best Model
```bash
make promote
```
⚡ 5. Serve with FastAPI
```bash
make start-api
```
☁️ 6. Deploy with KServe
```bash
make deploy-kserve
```
Or use the quickstart:
```bash
make kserve-up
make kserve-predict
```
## 🧪 CI/CD & Automation
This project includes:

GitHub Actions workflows for:

Automated training and MLflow logging

Artifact pushing to S3

Model promotion and deployment triggers

## 🧠 Future Extensions
Model monitoring (drift, performance) with Prometheus/Grafana

Auto-retraining with Airflow or GitHub cron jobs

Authentication + watchlists in the frontend
