from fastapi import FastAPI, Query, UploadFile, File
from fastapi.responses import FileResponse, JSONResponse
import yt_dlp
import os
import time

app = FastAPI()

OUTPUT_DIR = "/tmp/downloads"
os.makedirs(OUTPUT_DIR, exist_ok=True)

COOKIES_FILE = "youtube_cookies.txt"

@app.post("/upload-cookies")
async def upload_cookies(file: UploadFile = File(...)):
    with open(COOKIES_FILE, "wb") as f:
        f.write(await file.read())
    return {"status": "cookies uploaded"}

@app.get("/download")
def download_video(url: str = Query(...)):
    try:
        timestamp = int(time.time())
        filename = f"video_{timestamp}.mp4"
        output_path = os.path.join(OUTPUT_DIR, filename)

        # Determine correct Referer based on the URL
        if "instagram.com" in url:
            referer = "https://www.instagram.com/"
        elif "tiktok.com" in url:
            referer = "https://www.tiktok.com/"
        else:
            referer = "https://www.youtube.com/"

        # Determine correct User-Agent based on the URL
        if "vimeo.com" in url:
            user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        else:
            user_agent = "Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro Build/TQ2A.230505.002) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36"

        ydl_opts = {
            'outtmpl': output_path,
            'format': 'bestvideo+bestaudio/best',
            'merge_output_format': 'mp4',
            'ffmpeg_location': 'C:\\ffmpeg\\bin\\ffmpeg.exe',
            'noplaylist': True,
            'quiet': True,
            'postprocessors': [{
                'key': 'FFmpegVideoConvertor',
                'preferedformat': 'mp4',
            }],
            'extractor_args': {
                'youtube': ['player_client=android'],
            },
            'mark_watched': False,
            'http_headers': {
                'User-Agent': user_agent,
                'Referer': referer,
                'Accept-Language': 'en-US,en;q=0.9',
            }
        }

        if "dailymotion.com" in url:
            ydl_opts['force_generic_extractor'] = True

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])

        return FileResponse(path=output_path, filename=filename, media_type='video/mp4')

    except Exception as e:
        return JSONResponse(content={"error": str(e)})

        return JSONResponse(content={"error": str(e)})
