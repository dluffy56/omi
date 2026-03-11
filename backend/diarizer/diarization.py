import os
import uuid
import logging

import torch
from fastapi import HTTPException, UploadFile
from pyannote.audio import Pipeline

logger = logging.getLogger(__name__)


def _load_pipeline(model_name: str, hf_token: str | None):
    try:
        return Pipeline.from_pretrained(model_name, token=hf_token)
    except TypeError:
        try:
            return Pipeline.from_pretrained(model_name, use_auth_token=hf_token)
        except Exception as e:
            logger.exception(f"Failed to load diarization pipeline with use_auth_token: {e}")
            return None
    except Exception as e:
        logger.exception(f"Failed to load diarization pipeline: {e}")
        return None


# Instantiate pretrained speaker diarization pipeline
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
diarization_pipeline = _load_pipeline("pyannote/speaker-diarization-community-1", os.getenv('HUGGINGFACE_TOKEN'))
if diarization_pipeline is not None:
    diarization_pipeline = diarization_pipeline.to(device)

os.makedirs('_temp', exist_ok=True)


def diarization_endpoint(file: UploadFile):
    """
    Perform speaker diarization on an audio file.

    Args:
        file: Audio file (wav, mp3, etc.)

    Returns:
        List of diarization segments with speaker labels, start time, end time
    """
    if diarization_pipeline is None:
        raise HTTPException(
            status_code=503,
            detail="Diarization model unavailable. Check HUGGINGFACE_TOKEN and gated model access.",
        )

    upload_id = str(uuid.uuid4())
    file_path = f"_temp/{upload_id}_{file.filename}"

    try:
        # Save uploaded file
        with open(file_path, 'wb') as f:
            f.write(file.file.read())

        # Run diarization
        output = diarization_pipeline(file_path)

        # Extract segments
        data = []
        for turn, speaker in output.speaker_diarization:
            data.append(
                {
                    'speaker': speaker,
                    'start': turn.start,
                    'end': turn.end,
                    'duration': turn.end - turn.start,
                }
            )

        return data

    finally:
        # Clean up temporary file
        if os.path.exists(file_path):
            os.remove(file_path)
