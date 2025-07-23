import json
from pathlib import Path
from app.services import whisper_service

PROCESSED_DIR = Path("processed")
PROCESSED_DIR.mkdir(exist_ok=True)

def run_pipeline(job_id: str, input_path: str):
    result = whisper_service.transcribe(input_path)
    out_path = PROCESSED_DIR / f"{job_id}_transcript.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
