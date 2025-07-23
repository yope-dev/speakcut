from fastapi import APIRouter, UploadFile, File
from uuid import uuid4
from app.services import storage, pipeline
from app.models.schema import UploadResponse

router = APIRouter()

@router.post("/upload", response_model=UploadResponse)
async def upload_video(file: UploadFile = File(...)):
    job_id = str(uuid4())
    input_path = storage.save_upload(file, job_id)
    pipeline.run_pipeline(job_id, input_path)
    return UploadResponse(job_id=job_id, status="processing")
