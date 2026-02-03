
# scripts/evaluate_and_promote.py
import os
import mlflow
from mlflow.tracking import MlflowClient

MODEL_NAME = "ChurnPredictionRandomForest"
METRIC = "accuracy"
MIN_THRESHOLD = 0.84

mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000"))


client = MlflowClient()


# Get latest model version (by version number)
versions = client.search_model_versions(f"name='{MODEL_NAME}'")
if not versions:
    print("❌ No new models to promote.")
    exit(0)

latest = max(versions, key=lambda v: int(v.version))
version = latest.version
run_id = latest.run_id

# Fetch accuracy metric
run = client.get_run(run_id)
accuracy = float(run.data.metrics.get(METRIC, 0))

print(f"🔍 Model v{version} accuracy: {accuracy}")
if accuracy >= MIN_THRESHOLD:
    print("✅ Promoting model to Production...")
    client.set_registered_model_alias(MODEL_NAME, "production", version)
else:
    print("⚠️ Model does not meet accuracy threshold. Not promoted.")

