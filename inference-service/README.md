# Inference Service

Minimal Python sidecar for FarmMapping tree-species prediction.

## Endpoints

- `GET /health`
- `POST /predict`

## Required Environment Variables

- `MODEL_PATH`

## Optional Environment Variables

- `LABELS_PATH`
- `MODEL_BACKBONE`
- `MODEL_DEVICE`
- `MODEL_VERSION`
- `UNKNOWN_CONFIDENCE_THRESHOLD`

`LABELS_PATH` defaults to `<MODEL_PATH parent>/labels.json`.

## Bundled Model

The production image bakes the promoted model bundle into `/models`.

- `model-bundle/tree_classifier_resnet34.pth`
- `model-bundle/labels.json`
- `model-bundle/model_config.json`

The Dockerfile sets defaults so the container starts without a host bind mount.

## Local Run

```powershell
cd inference-service
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:MODEL_PATH='C:\path\to\tree_classifier_resnet34.pth'
$env:LABELS_PATH='C:\path\to\labels.json'
.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000
```

## Example Request

```powershell
curl -X POST "http://localhost:8000/predict?top_k=3" `
  -F "file=@C:\path\to\photo.jpg"
```
