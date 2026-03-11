from __future__ import annotations

import io
import json
import os
import torch
import torch.nn as nn
from PIL import Image, UnidentifiedImageError
from dataclasses import dataclass
from pathlib import Path
from torchvision import models, transforms
from typing import Any

DEFAULT_TOP_K = 3
DEFAULT_UNKNOWN_CONFIDENCE_THRESHOLD = 0.75


class PredictionError(Exception):
    """Raised when the inference service cannot process a request."""


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise PredictionError(f"Missing required environment variable: {name}")
    return value


def load_model_backbone(model_path: Path, requested_backbone: str | None = None) -> str:
    """Infer the backbone from model_config.json unless explicitly provided."""
    if requested_backbone:
        return requested_backbone

    config_path = model_path.parent / "model_config.json"
    if config_path.exists():
        with config_path.open("r", encoding="utf-8") as handle:
            config = json.load(handle)
        backbone = config.get("backbone")
        if backbone:
            return str(backbone)

    if "resnet50" in model_path.name.lower():
        return "resnet50"
    return "resnet34"


def build_backbone_model(backbone_name: str, num_classes: int) -> nn.Module:
    """Create the configured ResNet backbone for inference."""
    normalized_name = backbone_name.lower()
    if normalized_name == "resnet34":
        model = models.resnet34()
    elif normalized_name == "resnet50":
        model = models.resnet50()
    else:
        raise PredictionError(f"Unsupported backbone: {backbone_name}")

    num_features = model.fc.in_features
    model.fc = nn.Linear(num_features, num_classes)
    return model


def resolve_device(device_name: str) -> torch.device:
    """Map env configuration to a torch device."""
    normalized_name = device_name.strip().lower()
    if normalized_name in {"", "auto"}:
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    return torch.device(normalized_name)


@dataclass(frozen=True)
class PredictorConfig:
    model_path: Path
    labels_path: Path
    backbone: str | None
    device_name: str
    unknown_confidence_threshold: float
    model_version: str

    @classmethod
    def from_env(cls) -> "PredictorConfig":
        model_path = Path(require_env("MODEL_PATH")).expanduser().resolve()
        labels_default = model_path.parent / "labels.json"
        labels_path = Path(os.getenv("LABELS_PATH", str(labels_default))).expanduser().resolve()
        backbone = os.getenv("MODEL_BACKBONE")
        device_name = os.getenv("MODEL_DEVICE", "auto")
        unknown_confidence_threshold = float(
            os.getenv(
                "UNKNOWN_CONFIDENCE_THRESHOLD",
                str(DEFAULT_UNKNOWN_CONFIDENCE_THRESHOLD),
            )
        )
        model_version = os.getenv("MODEL_VERSION", model_path.parent.name or model_path.stem)

        return cls(
            model_path=model_path,
            labels_path=labels_path,
            backbone=backbone,
            device_name=device_name,
            unknown_confidence_threshold=unknown_confidence_threshold,
            model_version=model_version,
        )


class TreePredictor:
    """Load model artifacts once and serve predictions from memory."""

    def __init__(self, config: PredictorConfig) -> None:
        self.config = config
        self.device = resolve_device(config.device_name)

        if not config.model_path.exists():
            raise PredictionError(f"Model weights not found: {config.model_path}")
        if not config.labels_path.exists():
            raise PredictionError(f"Labels file not found: {config.labels_path}")

        with config.labels_path.open("r", encoding="utf-8") as handle:
            labels_dict = json.load(handle)

        self.class_names = [labels_dict[str(index)] for index in range(len(labels_dict))]
        self.num_classes = len(self.class_names)
        self.backbone = load_model_backbone(config.model_path, requested_backbone=config.backbone)

        self.model = build_backbone_model(backbone_name=self.backbone, num_classes=self.num_classes)
        self.model.load_state_dict(
            torch.load(config.model_path, map_location=self.device, weights_only=True)
        )
        self.model = self.model.to(self.device)
        self.model.eval()

        self.transform = transforms.Compose(
            [
                transforms.Resize(256),
                transforms.CenterCrop(224),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ]
        )

    def summary(self) -> dict[str, Any]:
        return {
            "model_version": self.config.model_version,
            "model_path": str(self.config.model_path),
            "labels_path": str(self.config.labels_path),
            "backbone": self.backbone,
            "device": str(self.device),
            "num_classes": self.num_classes,
            "class_names": self.class_names,
            "unknown_confidence_threshold": self.config.unknown_confidence_threshold,
        }

    def _unknown_decision(self, predictions: list[dict[str, Any]]) -> tuple[bool, list[str]]:
        if not predictions:
            return False, []

        reasons: list[str] = []
        top_confidence = float(predictions[0]["confidence"])
        threshold = self.config.unknown_confidence_threshold

        if top_confidence < threshold:
            reasons.append(
                f"top confidence {top_confidence:.2%} below threshold {threshold:.2%}"
            )

        return bool(reasons), reasons

    def predict_bytes(self, image_bytes: bytes, top_k: int = DEFAULT_TOP_K) -> dict[str, Any]:
        if not image_bytes:
            raise PredictionError("Uploaded file is empty.")

        try:
            with Image.open(io.BytesIO(image_bytes)) as image:
                image = image.convert("RGB")
        except UnidentifiedImageError as exc:
            raise PredictionError("Uploaded file is not a valid image.") from exc

        image_tensor = self.transform(image).unsqueeze(0).to(self.device)

        with torch.no_grad():
            outputs = self.model(image_tensor)
            probabilities = torch.nn.functional.softmax(outputs, dim=1)

        top_probs, top_indices = torch.topk(probabilities, min(top_k, self.num_classes))

        predictions: list[dict[str, Any]] = []
        for prob, idx in zip(top_probs[0], top_indices[0]):
            predictions.append(
                {
                    "label": self.class_names[idx.item()],
                    "confidence": float(prob.item()),
                }
            )

        second_confidence = predictions[1]["confidence"] if len(predictions) > 1 else 0.0
        confidence_margin = predictions[0]["confidence"] - second_confidence
        is_unknown, unknown_reasons = self._unknown_decision(predictions)

        raw_top_prediction = predictions[0]["label"]
        top_prediction = "unknown" if is_unknown else raw_top_prediction

        return {
            "model_version": self.config.model_version,
            "predictions": predictions,
            "raw_top_prediction": raw_top_prediction,
            "top_prediction": top_prediction,
            "top_confidence": predictions[0]["confidence"],
            "top2_margin": confidence_margin,
            "is_unknown": is_unknown,
            "unknown_reasons": unknown_reasons,
            "backbone": self.backbone,
            "device": str(self.device),
        }
