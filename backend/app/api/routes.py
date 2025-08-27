import os

from fastapi import APIRouter, UploadFile, File, HTTPException
from uuid import uuid4
from app.services import storage, pipeline
from app.models.schema import UploadResponse
from fastapi.responses import FileResponse
from pathlib import Path

PROCESSED_DIR = Path("processed")
PROCESSED_DIR.mkdir(exist_ok=True)
router = APIRouter()

@router.post("/upload", response_model=UploadResponse)
async def upload_video(file: UploadFile = File(...)):
    job_id = str(uuid4())
    input_path = storage.save_upload(file, job_id)
    pipeline.run_pipeline(job_id, input_path)
    return UploadResponse(job_id=job_id, status="processing")


@router.get("/result/{job_id}")
async def get_result(job_id: str):
    # Look for any processed file with the job_id
    processed_files = list(PROCESSED_DIR.glob(f"{job_id}_processed.*"))

    if not processed_files:
        raise HTTPException(status_code=404, detail="Processed file not found")

    # Get the first processed file (there should only be one)
    processed_file = processed_files[0]

    # Determine media type based on file extension
    extension = processed_file.suffix.lower()
    media_types = {
        '.mp4': 'video/mp4',
        '.mov': 'video/quicktime',
        '.avi': 'video/x-msvideo',
        '.mp3': 'audio/mpeg',
        '.m4a': 'audio/mp4',
        '.wav': 'audio/wav'
    }

    media_type = media_types.get(extension, 'application/octet-stream')

    return FileResponse(
        path=processed_file,
        media_type=media_type,
        filename=processed_file.name
    )


@router.get("/status/{job_id}")
async def get_status(job_id: str):
    transcript_path = PROCESSED_DIR / f"{job_id}_transcript.json"

    # Check for processed files with different extensions
    processed_files = list(PROCESSED_DIR.glob(f"{job_id}_processed.*"))

    if processed_files:
        return {"job_id": job_id, "status": "completed", "extension": os.path.splitext(processed_files[0])[1]}
    elif transcript_path.exists():
        return {"job_id": job_id, "status": "processing"}
    else:
        raise HTTPException(status_code=404, detail="Job not found")