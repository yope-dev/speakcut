from pathlib import Path
from fastapi import UploadFile

TEMP_DIR = Path("temp")
TEMP_DIR.mkdir(exist_ok=True)

def save_upload(file: UploadFile, job_id: str) -> str:
    file_path = TEMP_DIR / f"{job_id}.mp4"
    with open(file_path, "wb") as f:
        f.write(file.file.read())
    return str(file_path)
