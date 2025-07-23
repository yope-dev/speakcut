import whisper

model = whisper.load_model("base")  # можна tiny / small / medium

def transcribe(video_path: str) -> dict:
    result = model.transcribe(video_path)
    return result
