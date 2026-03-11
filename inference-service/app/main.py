from __future__ import annotations

from contextlib import asynccontextmanager
from fastapi import FastAPI, File, HTTPException, Query, Request, UploadFile
from pydantic import BaseModel

from .predictor import DEFAULT_TOP_K, PredictionError, PredictorConfig, TreePredictor


class PredictionItem(BaseModel):
    label: str
    confidence: float


class PredictionResponse(BaseModel):
    model_version: str
    predictions: list[PredictionItem]
    raw_top_prediction: str
    top_prediction: str
    top_confidence: float
    top2_margin: float
    is_unknown: bool
    unknown_reasons: list[str]
    backbone: str
    device: str


class HealthResponse(BaseModel):
    status: str
    model_version: str
    model_path: str
    labels_path: str
    backbone: str
    device: str
    num_classes: int
    class_names: list[str]
    unknown_confidence_threshold: float


@asynccontextmanager
async def lifespan(app: FastAPI):
    config = PredictorConfig.from_env()
    app.state.predictor = TreePredictor(config)
    yield


app = FastAPI(
    title="FarmMapping Tree Inference Sidecar",
    version="0.1.0",
    lifespan=lifespan,
)


@app.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    predictor: TreePredictor = request.app.state.predictor
    return HealthResponse(status="ok", **predictor.summary())


@app.post("/predict", response_model=PredictionResponse)
async def predict(
    request: Request,
    file: UploadFile = File(...),
    top_k: int = Query(DEFAULT_TOP_K, ge=1, le=10),
) -> PredictionResponse:
    image_bytes = await file.read()
    predictor: TreePredictor = request.app.state.predictor

    try:
        prediction = predictor.predict_bytes(image_bytes=image_bytes, top_k=top_k)
    except PredictionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Prediction failed.") from exc

    return PredictionResponse(**prediction)
