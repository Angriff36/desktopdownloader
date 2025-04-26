@echo off

:: Kill any old uvicorn server running on port 8000
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000') do taskkill /F /PID %%a

:: Start uvicorn backend
start "Uvicorn Server" cmd /k "cd /d C:\OrganizedData\scripts\yt-downloader && uvicorn main:app --host 0.0.0.0 --port 8000"

:: Small wait to let backend start
timeout /t 2 >nul

:: Start Flutter frontend
cd /d C:\Users\shrug\AppData\Local\Android\Sdk\cmdline-tools\x_video_downloader
flutter run -d windows
