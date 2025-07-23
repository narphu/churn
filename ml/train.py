# ml/train.py
import os
import sys
import joblib
import mlflow
import mlflow.sklearn
import pandas as pd
from datetime import datetime
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, roc_auc_score, f1_score, confusion_matrix, ConfusionMatrixDisplay, classification_report

from sklearn.model_selection import train_test_split
import matplotlib.pyplot as plt
from mlflow.models.signature import infer_signature

# === Load & Prepare Dataset ===
df = pd.read_csv("data/churn_dataset.csv")
print("✅ Loaded dataset:", df.shape)

X = df.drop(columns=["customer_id", "churned", "recency_days", "active_days", "order_count"])
y = df["churned"]

# Drop all non-numeric columns
X = X.select_dtypes(include=["number"])

# Impute missing values with median (or mean)
imputer = SimpleImputer(strategy="median")
X = pd.DataFrame(imputer.fit_transform(X), columns=X.columns)

y = df["churned"]

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, stratify=y, random_state=42)


# === Set MLflow tracking ===
mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("churn-randomforest")

# === Model Params ===
model_params = {"n_estimators":100, "random_state":42, "class_weight":"balanced",  "features": ",".join(X.columns)}

run_name = f"RF-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

with mlflow.start_run(run_name=run_name):
    # Train model
    model = RandomForestClassifier(**model_params)
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    # Metrics
    acc = accuracy_score(y_test, y_pred)
    roc = roc_auc_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)

    # Log params & metrics
    mlflow.log_params(model_params)
    mlflow.log_metrics({"accuracy": acc, "roc_auc": roc, "f1_score": f1})
    # print(df["churned"].value_counts())

    # print("✅ Train shape:", X_train.shape, "| Test shape:", X_test.shape)
    # print("🧪 Target balance (train):", y_train.value_counts(normalize=True).to_dict())
    # print("🧪 Target balance (test):", y_test.value_counts(normalize=True).to_dict())


    # Confusion matrix
    cm = confusion_matrix(y_test, y_pred)
    disp = ConfusionMatrixDisplay(confusion_matrix=cm)
    disp.plot()
    cm_path = "confusion_matrix.png"

    # print(classification_report(y_test, y_pred, digits=4))
    # print("Confusion matrix:\n", confusion_matrix(y_test, y_pred))
    plt.savefig(cm_path)
    plt.close()
    mlflow.log_artifact(cm_path)

    # Infer model signature
    signature = infer_signature(X_test, y_pred)
    input_example = X_test.iloc[:3]

    # Log model with signature + example
    mlflow.sklearn.log_model(
        sk_model=model,
        artifact_path="model",
        signature=signature,
        input_example=input_example,
        registered_model_name="ChurnPredictionRandomForest"
    )

    # Save locally for serving
    os.makedirs("models/randomforest", exist_ok=True)
    joblib.dump(model, "models/randomforest/churn_model.joblib")

    print("✅ Model training complete.")
    print(f"📊 Accuracy: {acc:.4f}, ROC AUC: {roc:.4f}, F1 Score: {f1:.4f}")
