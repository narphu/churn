# api/main.py
from fastapi import FastAPI
from schema import ChurnInput
from inference import predict
from explain import explain_prediction

app = FastAPI()

@app.get("/")
def health():
    return {"status": "✅ up"}

@app.post("/predict")
def predict_churn(input: ChurnInput):
    preds = predict(input.data, input.columns)
    return {"predictions": preds}

@app.post("/explain")
def explain(payload: ChurnInput):
    return explain_prediction(payload.data, payload.columns)

