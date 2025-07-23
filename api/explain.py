# api/explain.py
import shap
import pandas as pd
import os
import matplotlib.pyplot as plt
from inference import model, FEATURES

explainer = shap.TreeExplainer(model)

def explain_prediction(data: list[list], columns: list[str]) -> dict:
    df = pd.DataFrame(data, columns=columns)

    # Ensure columns match model features
    missing = [col for col in FEATURES if col not in df.columns]
    if missing:
        raise ValueError(f"Missing required features: {missing}")

    # Align and order the columns as expected by the model
    df = df[FEATURES]

    shap_values = explainer.shap_values(df)

    save_shap_plot(df, shap_values)

    return {
        "base_value": explainer.expected_value[1],
        "shap_values": shap_values[1].tolist(),
        "feature_values": df.values.tolist(),
        "features": df.columns.tolist()
    }


def save_shap_plot(df: pd.DataFrame, shap_vals: list, out_path: str = "artifacts/shap_explain.png"):
    shap.summary_plot(shap_vals[1], df, show=False)
    os.makedirs("artifacts", exist_ok=True)
    plt.savefig(out_path)
    plt.close()

