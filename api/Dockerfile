# api/Dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir fastapi uvicorn mlflow==2.17.2 pandas scikit-learn==1.3.2 shap==0.44.1 matplotlib

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]