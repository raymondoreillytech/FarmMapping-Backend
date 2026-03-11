FROM python:3.12.8-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MODEL_DEVICE=cpu \
    MODEL_PATH=/models/tree_classifier_resnet34.pth \
    LABELS_PATH=/models/labels.json \
    MODEL_VERSION=sweep_20260310_232455-resnet34_full_cosine_bs40_90ep \
    UNKNOWN_CONFIDENCE_THRESHOLD=0.75

WORKDIR /app

COPY requirements.txt .

RUN python -m pip install --upgrade pip && \
    python -m pip install --extra-index-url https://download.pytorch.org/whl/cpu -r requirements.txt

COPY app ./app
COPY model-bundle /models

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
