import json
import os
import re
import string
import subprocess
from pathlib import Path
from app.services import whisper_service


PROCESSED_DIR = Path("processed")
PROCESSED_DIR.mkdir(exist_ok=True)

FILLER_PATTERNS = [
    r'(uh|um|hm+|hm|erm+|uhh+|ah+|okay|ok|so|well|right|like|you know|basically|i mean|actually|literally|totally|really|very|just)'
]


def run_pipeline(job_id: str, input_path: str):
    result = whisper_service.transcribe(input_path)
    extention = os.path.splitext(input_path)[1]
    cleaned_result = clean_transcript(result)
    out_path = PROCESSED_DIR / f"{job_id}_transcript.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(cleaned_result, f, ensure_ascii=False, indent=2)
    trim_with_ffmpeg(input_path, cleaned_result, job_id, extention)


def clean_transcript(transcript):
    if isinstance(transcript, dict) and 'segments' in transcript:
        cleaned_segments = []
        for segment in transcript['segments']:
            text = segment.get('text', '')
            for pattern in FILLER_PATTERNS:
                text = re.sub(pattern, '', text, flags=re.IGNORECASE)
            if len(text.strip()) > 2:
                segment['text'] = text
                cleaned_segments.append(segment)
        transcript['segments'] = cleaned_segments
    return transcript


def normalize_word(word):
    return word.strip().lower().translate(str.maketrans('', '', string.punctuation))


def get_clean_intervals_from_words(transcript, filler_patterns, start_threshold=0.2, end_threshold=0.2):
    words = []
    for segment in transcript.get('segments', []):
        words.extend(segment.get('words', []))

    clean_intervals = []
    current_start = None

    for word_info in words:
        raw_word = word_info['word'].strip().lower()
        norm_word = normalize_word(raw_word)
        start = word_info['start']
        is_filler = any(re.fullmatch(pattern, norm_word, flags=re.IGNORECASE) for pattern in filler_patterns)
        if is_filler:
            if current_start is not None:
                clean_intervals.append((current_start, max(0.0, start - start_threshold)))
                current_start = None
        else:
            if current_start is None:
                current_start = max(0.0, start - start_threshold)

    if current_start is not None:
        clean_intervals.append((current_start, words[-1]['end'] + end_threshold))

    return [interval for interval in clean_intervals if interval[1] - interval[0] > 0.3]


def is_video_file(file_path):
    """Check if file contains video stream"""
    cmd = [
        "ffprobe",
        "-v", "quiet",
        "-print_format", "json",
        "-show_streams",
        str(file_path)
    ]
    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        data = json.loads(result.stdout)
        for stream in data.get("streams", []):
            if stream.get("codec_type") == "video":
                return True
        return False
    except Exception:
        return False


def cut_segment(input_path, start, end, output_path):
    """Cut audio or video segment based on input file type"""
    if is_video_file(input_path):
        # Handle video files
        command = [
            "ffmpeg",
            "-y",
            "-ss", str(start),
            "-to", str(end),
            "-i", str(input_path),
            "-c:v", "libx264",
            "-c:a", "aac",
            "-strict", "experimental",
            str(output_path)
        ]
    else:
        # Handle audio-only files
        input_ext = Path(input_path).suffix.lower()
        output_ext = Path(output_path).suffix.lower()

        if output_ext == '.mp3':
            # Use MP3 encoding for MP3 output
            command = [
                "ffmpeg",
                "-y",
                "-ss", str(start),
                "-to", str(end),
                "-i", str(input_path),
                "-c:a", "libmp3lame",
                str(output_path)
            ]
        else:
            # Use AAC encoding for other audio formats (m4a, etc.)
            command = [
                "ffmpeg",
                "-y",
                "-ss", str(start),
                "-to", str(end),
                "-i", str(input_path),
                "-c:a", "aac",
                "-strict", "experimental",
                str(output_path)
            ]

    subprocess.run(command, check=True)


def concatenate_segments(segment_paths, output_path):
    """Concatenate audio or video segments"""
    list_path = output_path.parent / "concat_list.txt"
    with open(list_path, "w", encoding="utf-8") as f:
        for p in segment_paths:
            f.write(f"file '{p.resolve()}'\n")

    # Determine if we're dealing with audio or video
    is_video = is_video_file(segment_paths[0]) if segment_paths else False

    if is_video:
        command = [
            "ffmpeg",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", str(list_path),
            "-c", "copy",
            str(output_path)
        ]
    else:
        # For audio files, use aac or copy codec based on extension
        output_ext = Path(output_path).suffix.lower()
        if output_ext == '.mp3':
            command = [
                "ffmpeg",
                "-y",
                "-f", "concat",
                "-safe", "0",
                "-i", str(list_path),
                "-c:a", "libmp3lame",
                str(output_path)
            ]
        else:
            command = [
                "ffmpeg",
                "-y",
                "-f", "concat",
                "-safe", "0",
                "-i", str(list_path),
                "-c:a", "aac",
                "-strict", "experimental",
                str(output_path)
            ]

    subprocess.run(command, check=True)
    try:
        os.remove(list_path)
    except Exception as e:
        print(f"Failed to delete temp file {list_path}: {e}")


def trim_with_ffmpeg(input_path, transcript, job_id, extension):
    clean_intervals = get_clean_intervals_from_words(transcript, FILLER_PATTERNS)
    if not clean_intervals:
        return

    segment_paths = []
    for idx, (start, end) in enumerate(clean_intervals):
        # Determine output extension based on input and content type
        if is_video_file(input_path):
            out_ext = extension
        else:
            # For audio, preserve original extension or use .m4a for AAC
            input_ext = Path(input_path).suffix.lower()
            if input_ext == '.mp3':
                out_ext = '.mp3'
            else:
                out_ext = '.m4a'

        out_path = PROCESSED_DIR / f"{job_id}_part_{idx}{out_ext}"
        cut_segment(input_path, start, end, out_path)
        segment_paths.append(out_path)

    # Determine final output extension
    if is_video_file(input_path):
        final_ext = extension
    else:
        input_ext = Path(input_path).suffix.lower()
        if input_ext == '.mp3':
            final_ext = '.mp3'
        else:
            final_ext = '.m4a'

    final_path = PROCESSED_DIR / f"{job_id}_processed{final_ext}"
    concatenate_segments(segment_paths, final_path)

    # Clean up temporary segments
    for path in segment_paths:
        try:
            os.remove(path)
        except Exception as e:
            print(f"Failed to delete temp file {path}: {e}")
