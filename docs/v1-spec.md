# Class Attendance System V1

## Product Goal

Build a mobile-only class attendance system that provides stronger attendance proof than a simple tap-in, while also supporting lecture audio upload for AI transcription and summarization.

## V1 Decisions

- Mobile-only client built with Flutter
- REST API backend
- PostgreSQL as the target database
- Attendance proof uses short-lived session code plus campus Wi-Fi validation
- Lecturer can manually override attendance records
- Lecture processing runs asynchronously after upload
- No biometric verification in V1

## Core Roles

- Student
- Lecturer

## Primary Lecturer Flow

1. Sign in
2. Create and start a class session
3. Share a rotating session code with students
4. Record or upload lecture audio
5. End session
6. Review attendance and AI-generated lecture summary
7. Override attendance records if needed

## Primary Student Flow

1. Sign in
2. View active class sessions for enrolled courses
3. Enter the short-lived session code
4. Submit attendance proof while connected to campus Wi-Fi
5. View attendance result and lecture summary when available

## Attendance Rules

- `Present`: student joins within 20 minutes of session start
- `Late`: student joins after 20 minutes but before attendance closes
- `Absent`: student never joins before attendance closes
- `Excused`: lecturer manually marks the record
- `Invalid`: expired code, duplicate join, wrong class, or failed proof checks

## Attendance Proof

Attendance submission is valid only when:

- the student is authenticated
- the student is enrolled in the class
- the class session is active
- the submitted code matches the current valid session code
- the request is made from an approved campus Wi-Fi environment

## Wi-Fi Validation Strategy

V1 will validate campus presence using server-side network checks, with optional client-side Wi-Fi metadata capture when available.

Preferred checks:

1. Request originates from an approved campus public IP range
2. Client provides SSID or BSSID metadata when the platform allows it

Wi-Fi evidence supports attendance proof. Lecturer override remains available for edge cases.

## Attendance Window

- Session opens when the lecturer starts it
- Students are marked late after 20 minutes
- Attendance closes 40 minutes after session start by default
- Lecturer can close attendance earlier or override individual records later

## Lecture AI Processing

V1 uses asynchronous processing:

1. Lecturer records or uploads lecture audio
2. Backend stores the audio
3. Background processing transcribes the audio
4. Summarization generates:
   - short summary
   - key points
   - action items
5. Mobile app shows processing state and final results

## Non-Functional Targets

- Regular API responses should target under 2 seconds
- AI transcription and summarization are asynchronous and not bound by the 2 second target
- JWT-based authentication
- HTTPS in deployed environments
- Auditable attendance events

## V1 Backend Modules

- Authentication
- Courses and enrollments
- Session management
- Attendance
- Lecture uploads
- AI processing jobs
- Reports

## Key API Areas

- `POST /auth/login`
- `GET /me`
- `GET /courses`
- `POST /sessions`
- `POST /sessions/:id/start`
- `POST /sessions/:id/end`
- `GET /sessions/active`
- `POST /attendance/check-in`
- `PATCH /attendance/:id`
- `POST /lectures`
- `GET /lectures/:id`
- `GET /reports/sessions/:id`

## Initial Data Model

- `users`
- `courses`
- `enrollments`
- `sessions`
- `session_codes`
- `attendance_records`
- `lecture_recordings`
- `lecture_summaries`

## First Implementation Slice

The first implementation slice should cover:

- mock authentication
- course listing
- session creation and start
- active session lookup
- attendance check-in with code validation
- late versus present status calculation
- lecturer attendance override
- Flutter screens for lecturer and student flows

