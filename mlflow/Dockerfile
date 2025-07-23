FROM python:3.10-slim

WORKDIR /mlflow

# Install MLflow
RUN pip install mlflow

# Create folders for tracking and artifacts
RUN mkdir -p /mlflow/artifacts

# Set env vars (can override at runtime)
ENV MLFLOW_BACKEND_STORE_URI=sqlite:///mlflow.db
ENV MLFLOW_ARTIFACT_ROOT=/mlflow/artifacts

# Start MLflow Tracking Server
CMD ["mlflow", "server",  \
     "--host", "0.0.0.0",  \
     "--port", "5000"]
