# Class Attendance System

This repository contains the V1 implementation of a mobile-first class attendance system.

Current scope:

- stronger attendance proof using short-lived code plus campus Wi-Fi validation
- lecturer and student mobile flows
- REST API backend
- real phone audio recording and upload
- Groq Whisper transcription plus Groq summary generation
- transcript-text fallback when no provider key is configured

The working product definition is in [docs/v1-spec.md](docs/v1-spec.md).

## Repository Layout

- `backend/` Node.js REST API backed by PostgreSQL
- `mobile/` Flutter mobile client for lecturer and student flows
- `docker-compose.yml` local PostgreSQL container for development

## Demo Credentials

- Lecturer: `lecturer@campus.local` / `demo1234`
- Student: `student1@campus.local` / `demo1234`
- Student: `student2@campus.local` / `demo1234`
- Student: `student3@campus.local` / `demo1234`

## Local Run

1. Start PostgreSQL:
   `docker compose up -d attendance-postgres`
2. Configure the backend:
   - copy `backend/.env.example` to `backend/.env`
   - set `GROQ_API_KEY=...` if you want real audio transcription and summaries
3. Start the backend:
   `cd backend && npm install && node src/server.js`
4. Start the Flutter app:
   `cd mobile && flutter run`

## Notes

- The backend auto-creates schema and seeds demo data on startup.
- Real audio uploads are saved locally under `backend/uploads/` during processing.
- The mobile app defaults to `http://127.0.0.1:8080` and switches to `http://10.0.2.2:8080` on Android emulator.
- For a physical phone, change the API base URL in the login screen to your computer's LAN IP.
- If `GROQ_API_KEY` is missing, text-note summaries still work, but audio upload returns a clear configuration error.
