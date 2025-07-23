# Customer Churn Prediction Pipeline (MLOps)

## Overview

This project implements a **robust, production-ready MLOps pipeline** for customer churn prediction. It goes beyond just building a model — the full pipeline supports:

- Data preprocessing and feature engineering  
- Training multiple ML models with evaluation  
- SHAP-based model explainability  
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
- Feature explainability  
- Modern model serving (FastAPI, KServe)  

---

## 🧰 Project Features

| Feature                            | Description                                                                 |
|------------------------------------|-----------------------------------------------------------------------------|
| ✅ Preprocessing & Feature Store   | Cleans raw transactional/user data, creates engineered features             |
| 🤖 Multi-Model Training            | Supports models like XGBoost, Random Forest, Logistic Regression, etc.      |
| 📊 SHAP Explainability            | Computes and visualizes SHAP values for interpretability                    |
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
├── features/ # Feature engineering scripts
├── models/ # ML models and explainers
├── mlflow/ # MLflow tracking and registry setup
├── api/ # FastAPI server for local inference
├── notebooks/ # Optional EDA or SHAP visualizations
├── kserve/ # KServe YAMLs or InferenceService specs
├── Makefile # Declarative entry points for common tasks
├── requirements.txt # Python dependencies
└── README.md


---

## 🔄 Pipeline Flow (MLOps Lifecycle)

         ┌────────────┐
         │  Raw Data  │
         └────┬───────┘
              ▼
     ┌────────────────────┐
     │ Preprocessing + FE │  ← `features/engineering.py`
     └────┬───────────────┘
          ▼
    ┌──────────────────────┐
    │ Model Training │ ← train.py
    │ + Logging to MLflow │
    └────┬─────────────────┘
         ▼
    ┌──────────────────────┐
    │ SHAP Explainability │ ← explain.py
    └────┬─────────────────┘
         ▼
    ┌────────────────────────────┐
    │ MLflow Registry │ ← make promote model=ModelName
    │ - Staging/Production │
    └────┬───────────────────────┘
            ▼
    ┌──────────────────────┐ ┌─────────────────────┐
    │ FastAPI Inference │ ← local │ KServe Deployment │ ← cloud native
    └──────────────────────┘ └─────────────────────┘

---

## 🧪 Key Models Used

- **XGBoost** – High performance for tabular data  
- **Random Forest** – Strong baseline with interpretability  
- **Logistic Regression** – Good for calibration and linear separability  
- (More can be added modularly)

---

## 🧹 Preprocessing & Feature Engineering

Located in `features/engineering.py`, this includes:

- Handling missing values  
- Encoding categorical features  
- Deriving churn-relevant features like `recency_days`, `frequency`, `avg_order_value`, etc.  
- Outputs a clean dataset ready for modeling (`data/processed/churn.csv`)

---

## 🔍 SHAP Explainability

Located in `explain.py`:

- Uses TreeExplainer for tree-based models  
- Saves summary plots and feature importance visuals  
- Integrated with MLflow artifacts for UI inspection

---

## 📦 MLflow Usage

- **Tracking Server**: Set up in `mlflow_server.py`  
- **Model Logging**: During `train.py`, each run logs:  
  - Parameters, metrics  
  - `.pkl` model  
  - SHAP plots  
- **Promotion**: Use `make promote model=ModelName` to move from `staging → production`

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

## 🚀 Run the Project
🔧 1. Install Requirements
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```
⚙️ 2. Preprocess Data
```bash
make preprocess
```
🎯 3. Train Models
```bash
make train
```
📊 4. Generate SHAP Explanations
```bash
make explain
```
🧾 5. Run MLflow Tracking Server
```bash
make mlflow-ui
```
📈 6. Promote Best Model
``` bash
make promote model=xgboost
```
⚡ 7. Serve with FastAPI
```bash
make start-api
```
☁️ 8. Deploy with KServe
```bash
make deploy-kserve
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