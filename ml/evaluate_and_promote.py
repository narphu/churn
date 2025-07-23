# scripts/evaluate_and_promote.py
import mlflow
from mlflow.tracking import MlflowClient

MODEL_NAME = "ChurnPredictionRandomForest"
METRIC = "accuracy"
MIN_THRESHOLD = 0.84

mlflow.set_tracking_uri("http://localhost:5000")


client = MlflowClient()


# Get latest model in "None" stage
latest = client.get_latest_versions(MODEL_NAME, stages=["None"])
if not latest:
    print("❌ No new models to promote.")
    exit(0)

version = latest[0].version
run_id = latest[0].run_id

# Fetch accuracy metric
run = client.get_run(run_id)
accuracy = float(run.data.metrics.get(METRIC, 0))

print(f"🔍 Model v{version} accuracy: {accuracy}")
if accuracy >= MIN_THRESHOLD:
    print("✅ Promoting model to Production...")
    client.transition_model_version_stage(
        name=MODEL_NAME,
        version=version,
        stage="Production",
        archive_existing_versions=True
    )
else:
    print("⚠️ Model does not meet accuracy threshold. Not promoted.")


