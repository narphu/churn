# api/inference.py
import mlflow.sklearn
import pandas as pd

FEATURES = ["total_spent", "avg_order_value", "avg_review_score", "unique_products"]


mlflow.set_tracking_uri("http://host.docker.internal:5000")

MODEL_URI = "models:/ChurnPredictionRandomForest/Production"

def load_model():
    return mlflow.sklearn.load_model(MODEL_URI)

model = load_model()

def predict(data: list[list[float]], columns: list[str]):
    df = pd.DataFrame(data, columns=columns)
    # Keep only the features used during training
    df = df[FEATURES]
    preds = model.predict(df)
    return preds.tolist()