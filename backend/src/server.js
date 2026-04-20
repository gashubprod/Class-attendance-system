const syncFs = require('node:fs');
const fs = require('node:fs/promises');
const http = require('node:http');
const path = require('node:path');
const { Pool } = require('pg');
const {
  summarizeTranscriptWithGroq,
  transcribeAudioFile,
} = require('./groq');
const {
  ATTENDANCE_CLOSE_MINUTES,
  acceptedSessionCodes,
  attendanceStatusForCheckIn,
  codeExpiry,
  createJwt,
  generateLectureSummary,
  hashPassword,
  json,
  publicSessionView,
  randomId,
  readJson,
  sendError,
  verifyCampusNetwork,
  verifyJwt,
  verifyPassword,
} = require('./lib');

loadLocalEnv();

const config = {
  port: Number(process.env.PORT || 8080),
  databaseUrl:
    process.env.DATABASE_URL ||
    'postgres://attendance:attendance@localhost:5434/attendance',
  jwtSecret: process.env.JWT_SECRET || 'dev-attendance-secret',
  groqApiKey: process.env.GROQ_API_KEY || '',
  groqBaseUrl: process.env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1',
  groqTranscriptionModel:
    process.env.GROQ_TRANSCRIPTION_MODEL || 'whisper-large-v3-turbo',
  groqSummaryModel:
    process.env.GROQ_SUMMARY_MODEL || 'openai/gpt-oss-20b',
  groqLanguage: process.env.GROQ_LANGUAGE || 'en',
  uploadDir:
    process.env.UPLOAD_DIR || path.join(__dirname, '..', 'uploads'),
  maxUploadBytes: Number(process.env.MAX_AUDIO_UPLOAD_BYTES || 100 * 1024 * 1024),
  allowedSsids: (process.env.ALLOWED_WIFI_SSIDS || 'CampusNet')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
  allowedCidrs: (process.env.ALLOWED_NETWORK_CIDRS || '127.0.0.1/32,::1/128')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
};

const pool = new Pool({
  connectionString: config.databaseUrl,
});

const lectureJobs = new Map();

function loadLocalEnv() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!syncFs.existsSync(envPath)) {
    return;
  }

  const lines = syncFs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const separatorIndex = trimmed.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    if (!key || Object.prototype.hasOwnProperty.call(process.env, key)) {
      continue;
    }

    let value = trimmed.slice(separatorIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    process.env[key] = value;
  }
}

function mapSessionRow(row, currentTime = new Date()) {
  return {
    ...publicSessionView(row, currentTime),
    attendanceRecordId: row.attendance_record_id || null,
    attendanceStatus: row.attendance_status || null,
    checkedInAt: row.checked_in_at || null,
  };
}

function mapLectureRow(row) {
  return {
    id: row.id,
    sessionId: row.session_id,
    sessionTitle: row.session_title,
    sessionStatus: row.session_status,
    courseCode: row.course_code,
    courseTitle: row.course_title,
    fileName: row.file_name,
    sourceType: row.source_type,
    status: row.status,
    transcriptText: row.transcript_text,
    errorMessage: row.error_message,
    createdAt: row.created_at,
    processedAt: row.processed_at,
    summary: row.summary_id
      ? {
          id: row.summary_id,
          summary: row.summary,
          keyPoints: row.key_points || [],
          actionItems: row.action_items || [],
        }
      : null,
  };
}

function sanitizeFileName(fileName, fallback = 'lecture-audio.m4a') {
  const baseName = path.basename(String(fileName || '').trim() || fallback);
  const sanitized = baseName.replace(/[^a-zA-Z0-9._-]+/g, '-');
  return sanitized || fallback;
}

function extensionForUpload(fileName, mimeType) {
  const fromName = path.extname(fileName || '').toLowerCase();
  if (fromName) {
    return fromName;
  }

  return (
    {
      'audio/mp4': '.m4a',
      'audio/m4a': '.m4a',
      'audio/aac': '.aac',
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/wav': '.wav',
      'audio/x-wav': '.wav',
      'audio/webm': '.webm',
      'audio/ogg': '.ogg',
      'application/octet-stream': '.m4a',
    }[String(mimeType || '').toLowerCase()] || '.m4a'
  );
}

async function readBinaryRequest(req, maxBytes) {
  const chunks = [];
  let totalBytes = 0;

  for await (const chunk of req) {
    const buffer = Buffer.from(chunk);
    totalBytes += buffer.length;
    if (totalBytes > maxBytes) {
      const error = new Error(
        `Audio upload exceeded the ${Math.round(maxBytes / (1024 * 1024))} MB limit.`,
      );
      error.statusCode = 413;
      throw error;
    }
    chunks.push(buffer);
  }

  return Buffer.concat(chunks);
}

async function bootstrap() {
  const sqlPath = path.join(__dirname, '..', 'sql', 'init.sql');
  const schemaSql = await fs.readFile(sqlPath, 'utf8');
  await fs.mkdir(config.uploadDir, { recursive: true });
  await pool.query(schemaSql);
  await seedDemoData();
  await requeuePendingLectureJobs();
}

async function seedDemoData() {
  const lecturerId = 'usr_demo_lecturer';
  const studentAId = 'usr_demo_student_a';
  const studentBId = 'usr_demo_student_b';
  const studentCId = 'usr_demo_student_c';
  const courseId = 'crs_demo_mobile';
  const courseDistributedId = 'crs_demo_distributed';
  const courseSecurityId = 'crs_demo_security';
  const passwordHash = hashPassword('demo1234');

  await pool.query(
    `
      INSERT INTO users (id, name, email, password_hash, role)
      VALUES
        ($1, 'Dr. Amina Njoroge', 'lecturer@campus.local', $4, 'lecturer'),
        ($2, 'Alice Kamau', 'student1@campus.local', $4, 'student'),
        ($3, 'Brian Otieno', 'student2@campus.local', $4, 'student'),
        ($5, 'Carol Atieno', 'student3@campus.local', $4, 'student')
      ON CONFLICT (id) DO UPDATE
        SET name = EXCLUDED.name,
            email = EXCLUDED.email,
            password_hash = EXCLUDED.password_hash,
            role = EXCLUDED.role
    `,
    [lecturerId, studentAId, studentBId, passwordHash, studentCId],
  );

  await pool.query(
    `
      INSERT INTO courses (id, code, title, lecturer_id)
      VALUES
        ($1, 'CSM 301', 'Mobile Systems and Attendance', $4),
        ($2, 'CSM 305', 'Distributed Systems', $4),
        ($3, 'CSM 315', 'Secure Application Engineering', $4)
      ON CONFLICT (id) DO UPDATE
        SET code = EXCLUDED.code,
            title = EXCLUDED.title,
            lecturer_id = EXCLUDED.lecturer_id
    `,
    [courseId, courseDistributedId, courseSecurityId, lecturerId],
  );

  await pool.query(
    `
      INSERT INTO enrollments (course_id, student_id)
      VALUES
        ($1, $4), ($1, $5), ($1, $6),
        ($2, $4), ($2, $5), ($2, $6),
        ($3, $4), ($3, $5), ($3, $6)
      ON CONFLICT (course_id, student_id) DO NOTHING
    `,
    [
      courseId,
      courseDistributedId,
      courseSecurityId,
      studentAId,
      studentBId,
      studentCId,
    ],
  );

  await seedCompletedDemoSession({
    lecturerId,
    studentAId,
    studentBId,
    studentCId,
    courseId,
  });
}

async function seedCompletedDemoSession({
  lecturerId,
  studentAId,
  studentBId,
  studentCId,
  courseId,
}) {
  const sessionId = 'ses_demo_completed';
  const recordingId = 'lec_demo_completed';
  const summaryId = 'sum_demo_completed';
  const attendancePresentId = 'att_demo_present';
  const attendanceLateId = 'att_demo_late';
  const now = new Date();
  const startedAt = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const closesAt = new Date(startedAt.getTime() + ATTENDANCE_CLOSE_MINUTES * 60 * 1000);
  const endedAt = new Date(startedAt.getTime() + 75 * 60 * 1000);

  const transcriptText = `
  Today we covered the architecture for the class attendance system. We reviewed the mobile-first flow for lecturers and students, and we agreed to use rotating session codes with campus Wi-Fi validation instead of biometrics.
  The backend needs PostgreSQL, clear attendance status rules, and asynchronous lecture processing so that the mobile experience stays fast even after a long class recording.
  Students should be marked present within the first twenty minutes, late after that point, and absent once the attendance window closes.
  For tomorrow's demo, the lecturer should be able to create a session, expose the live code, collect attendance, override a student record when needed, and generate a lecture summary from notes or transcript text.
  Before the next class, everyone should review the summary, verify the attendance report, and prepare any feedback on the session workflow.
  `.trim();
  const summary = generateLectureSummary(transcriptText);

  await pool.query(
    `
      INSERT INTO sessions (
        id,
        course_id,
        lecturer_id,
        title,
        status,
        started_at,
        attendance_closes_at,
        ended_at,
        code_seed
      )
      VALUES ($1, $2, $3, 'Demo Wrap-up Lecture', 'ended', $4, $5, $6, 'seed_demo_completed')
      ON CONFLICT (id) DO UPDATE
        SET course_id = EXCLUDED.course_id,
            lecturer_id = EXCLUDED.lecturer_id,
            title = EXCLUDED.title,
            status = EXCLUDED.status,
            started_at = EXCLUDED.started_at,
            attendance_closes_at = EXCLUDED.attendance_closes_at,
            ended_at = EXCLUDED.ended_at,
            code_seed = EXCLUDED.code_seed
    `,
    [sessionId, courseId, lecturerId, startedAt.toISOString(), closesAt.toISOString(), endedAt.toISOString()],
  );

  await pool.query(
    `
      INSERT INTO attendance_records (id, session_id, student_id, status, checked_in_at)
      VALUES
        ($1, $3, $4, 'present', $6),
        ($2, $3, $5, 'late', $7),
        ($8, $3, $9, 'absent', NULL)
      ON CONFLICT (session_id, student_id) DO UPDATE
        SET status = EXCLUDED.status,
            checked_in_at = EXCLUDED.checked_in_at
    `,
    [
      attendancePresentId,
      attendanceLateId,
      sessionId,
      studentAId,
      studentBId,
      new Date(startedAt.getTime() + 8 * 60 * 1000).toISOString(),
      new Date(startedAt.getTime() + 27 * 60 * 1000).toISOString(),
      'att_demo_absent',
      studentCId,
    ],
  );

  await pool.query(
    `
      INSERT INTO lecture_recordings (
        id,
        session_id,
        file_name,
        status,
        transcript_text,
        source_type,
        processed_at
      )
      VALUES ($1, $2, 'demo-wrap-up.txt', 'completed', $3, 'text_demo', $4)
      ON CONFLICT (id) DO UPDATE
        SET session_id = EXCLUDED.session_id,
            file_name = EXCLUDED.file_name,
            status = EXCLUDED.status,
            transcript_text = EXCLUDED.transcript_text,
            source_type = EXCLUDED.source_type,
            processed_at = EXCLUDED.processed_at,
            error_message = NULL
    `,
    [recordingId, sessionId, transcriptText, endedAt.toISOString()],
  );

  await pool.query(
    `
      INSERT INTO lecture_summaries (id, recording_id, summary, key_points, action_items)
      VALUES ($1, $2, $3, $4::jsonb, $5::jsonb)
      ON CONFLICT (recording_id) DO UPDATE
        SET id = EXCLUDED.id,
            summary = EXCLUDED.summary,
            key_points = EXCLUDED.key_points,
            action_items = EXCLUDED.action_items
    `,
    [
      summaryId,
      recordingId,
      summary.summary,
      JSON.stringify(summary.keyPoints),
      JSON.stringify(summary.actionItems),
    ],
  );
}

async function requeuePendingLectureJobs() {
  const result = await pool.query(
    `
      SELECT id
      FROM lecture_recordings
      WHERE status IN ('pending', 'processing')
    `,
  );

  for (const row of result.rows) {
    queueLectureProcessing(row.id, 250);
  }
}

function queueLectureProcessing(recordingId, delayMs = 1500) {
  if (lectureJobs.has(recordingId)) {
    clearTimeout(lectureJobs.get(recordingId));
  }

  const timer = setTimeout(async () => {
    lectureJobs.delete(recordingId);
    try {
      await pool.query(
        `
          UPDATE lecture_recordings
          SET status = 'processing', error_message = NULL
          WHERE id = $1
        `,
        [recordingId],
      );

      const result = await pool.query(
        `
          SELECT id, file_name, transcript_text, source_type, storage_path, mime_type
          FROM lecture_recordings
          WHERE id = $1
        `,
        [recordingId],
      );
      const recording = result.rows[0];
      if (!recording) {
        return;
      }

      let transcriptText = String(recording.transcript_text || '').trim();

      if (recording.source_type === 'audio_upload') {
        transcriptText = await transcribeAudioFile({
          apiKey: config.groqApiKey,
          baseUrl: config.groqBaseUrl,
          model: config.groqTranscriptionModel,
          filePath: recording.storage_path,
          fileName: recording.file_name,
          mimeType: recording.mime_type,
          language: config.groqLanguage,
        });

        await pool.query(
          `
            UPDATE lecture_recordings
            SET transcript_text = $2
            WHERE id = $1
          `,
          [recordingId, transcriptText],
        );
      }

      if (!transcriptText) {
        throw new Error('No transcript text was available for summary generation.');
      }

      let summary;
      if (config.groqApiKey) {
        try {
          summary = await summarizeTranscriptWithGroq({
            apiKey: config.groqApiKey,
            baseUrl: config.groqBaseUrl,
            model: config.groqSummaryModel,
            transcriptText,
          });
        } catch (error) {
          summary = generateLectureSummary(transcriptText);
        }
      } else {
        summary = generateLectureSummary(transcriptText);
      }

      await pool.query(
        `
          INSERT INTO lecture_summaries (id, recording_id, summary, key_points, action_items)
          VALUES ($1, $2, $3, $4::jsonb, $5::jsonb)
          ON CONFLICT (recording_id) DO UPDATE
            SET summary = EXCLUDED.summary,
                key_points = EXCLUDED.key_points,
                action_items = EXCLUDED.action_items
        `,
        [
          randomId('sum'),
          recordingId,
          summary.summary,
          JSON.stringify(summary.keyPoints),
          JSON.stringify(summary.actionItems),
        ],
      );

      await pool.query(
        `
          UPDATE lecture_recordings
          SET status = 'completed',
              processed_at = NOW(),
              error_message = NULL
          WHERE id = $1
        `,
        [recordingId],
      );
    } catch (error) {
      await pool.query(
        `
          UPDATE lecture_recordings
          SET status = 'failed',
              processed_at = NOW(),
              error_message = $2
          WHERE id = $1
        `,
        [recordingId, error.message],
      );
    }
  }, delayMs);

  lectureJobs.set(recordingId, timer);
}

async function authenticate(req) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return null;
  }

  try {
    const payload = verifyJwt(header.slice('Bearer '.length), config.jwtSecret);
    const result = await pool.query(
      'SELECT id, name, email, role FROM users WHERE id = $1',
      [payload.sub],
    );
    return result.rows[0] || null;
  } catch {
    return null;
  }
}

function requireRole(user, res, role) {
  if (!user || user.role !== role) {
    sendError(res, 403, 'Forbidden');
    return false;
  }
  return true;
}

async function handleLogin(req, res) {
  const body = await readJson(req);
  const email = String(body.email || '').trim().toLowerCase();
  const password = String(body.password || '');

  if (!email || !password) {
    sendError(res, 400, 'Email and password are required.');
    return;
  }

  const result = await pool.query(
    'SELECT id, name, email, role, password_hash FROM users WHERE email = $1',
    [email],
  );
  const user = result.rows[0];

  if (!user || !verifyPassword(password, user.password_hash)) {
    sendError(res, 401, 'Invalid credentials.');
    return;
  }

  const token = createJwt(
    { sub: user.id, role: user.role, email: user.email },
    config.jwtSecret,
  );

  json(res, 200, {
    token,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    },
  });
}

async function listCourses(user) {
  if (user.role === 'lecturer') {
    const result = await pool.query(
      `
        SELECT id, code, title
        FROM courses
        WHERE lecturer_id = $1
        ORDER BY code
      `,
      [user.id],
    );
    return result.rows;
  }

  const result = await pool.query(
    `
      SELECT c.id, c.code, c.title
      FROM courses c
      INNER JOIN enrollments e ON e.course_id = c.id
      WHERE e.student_id = $1
      ORDER BY c.code
    `,
    [user.id],
  );
  return result.rows;
}

async function fetchSessions(user, { activeOnly = false } = {}) {
  const latestLectureJoin = `
    LEFT JOIN LATERAL (
      SELECT lr.id AS latest_lecture_id,
             lr.status AS latest_lecture_status,
             lr.created_at AS latest_lecture_created_at
      FROM lecture_recordings lr
      WHERE lr.session_id = s.id
      ORDER BY lr.created_at DESC
      LIMIT 1
    ) latest_lecture ON TRUE
  `;

  if (user.role === 'lecturer') {
    const result = await pool.query(
      `
        SELECT s.id, s.course_id, s.title, s.status, s.started_at, s.attendance_closes_at,
               s.ended_at, s.code_seed, c.code AS course_code, c.title AS course_title,
               latest_lecture.latest_lecture_id, latest_lecture.latest_lecture_status,
               latest_lecture.latest_lecture_created_at
        FROM sessions s
        INNER JOIN courses c ON c.id = s.course_id
        ${latestLectureJoin}
        WHERE s.lecturer_id = $1
          AND ${activeOnly ? "s.status = 'active'" : "s.status <> 'draft'"}
        ORDER BY COALESCE(s.started_at, s.created_at) DESC
      `,
      [user.id],
    );
    return result.rows.map((row) => mapSessionRow(row, new Date()));
  }

  const result = await pool.query(
    `
      SELECT s.id, s.course_id, s.title, s.status, s.started_at, s.attendance_closes_at,
             s.ended_at, s.code_seed, c.code AS course_code, c.title AS course_title,
             ar.id AS attendance_record_id, ar.status AS attendance_status, ar.checked_in_at,
             latest_lecture.latest_lecture_id, latest_lecture.latest_lecture_status,
             latest_lecture.latest_lecture_created_at
      FROM sessions s
      INNER JOIN courses c ON c.id = s.course_id
      INNER JOIN enrollments e ON e.course_id = c.id
      INNER JOIN attendance_records ar ON ar.session_id = s.id AND ar.student_id = e.student_id
      ${latestLectureJoin}
      WHERE e.student_id = $1
        AND ${activeOnly ? "s.status = 'active'" : "s.status <> 'draft'"}
      ORDER BY COALESCE(s.started_at, s.created_at) DESC
    `,
    [user.id],
  );

  return result.rows.map((row) => mapSessionRow(row, new Date()));
}

async function createSession(user, req, res) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const body = await readJson(req);
  const courseId = String(body.courseId || '').trim();
  const title = String(body.title || '').trim();

  if (!courseId) {
    sendError(res, 400, 'courseId is required.');
    return;
  }

  const courseResult = await pool.query(
    'SELECT id, code, title FROM courses WHERE id = $1 AND lecturer_id = $2',
    [courseId, user.id],
  );
  const course = courseResult.rows[0];

  if (!course) {
    sendError(res, 404, 'Course not found.');
    return;
  }

  const result = await pool.query(
    `
      INSERT INTO sessions (id, course_id, lecturer_id, title, status)
      VALUES ($1, $2, $3, $4, 'draft')
      RETURNING id, course_id, title, status, started_at, attendance_closes_at, ended_at, code_seed
    `,
    [randomId('ses'), courseId, user.id, title || `${course.code} session`],
  );

  json(res, 201, {
    session: publicSessionView(
      {
        ...result.rows[0],
        course_code: course.code,
        course_title: course.title,
      },
      new Date(),
    ),
  });
}

async function startSession(user, res, sessionId) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const sessionResult = await client.query(
      `
        SELECT s.id, s.course_id, s.lecturer_id, s.title, s.status, s.started_at,
               s.attendance_closes_at, s.ended_at, s.code_seed, c.code AS course_code, c.title AS course_title
        FROM sessions s
        INNER JOIN courses c ON c.id = s.course_id
        WHERE s.id = $1 AND s.lecturer_id = $2
        FOR UPDATE
      `,
      [sessionId, user.id],
    );
    const session = sessionResult.rows[0];

    if (!session) {
      await client.query('ROLLBACK');
      sendError(res, 404, 'Session not found.');
      return;
    }

    if (session.status !== 'draft') {
      await client.query('ROLLBACK');
      sendError(res, 409, 'Only draft sessions can be started.');
      return;
    }

    const now = new Date();
    const closeAt = new Date(
      now.getTime() + ATTENDANCE_CLOSE_MINUTES * 60 * 1000,
    );
    const codeSeed = randomId('seed');

    const updated = await client.query(
      `
        UPDATE sessions
        SET status = 'active',
            started_at = $2,
            attendance_closes_at = $3,
            code_seed = $4
        WHERE id = $1
        RETURNING id, course_id, lecturer_id, title, status, started_at, attendance_closes_at, ended_at, code_seed
      `,
      [session.id, now.toISOString(), closeAt.toISOString(), codeSeed],
    );

    await client.query(
      `
        INSERT INTO attendance_records (id, session_id, student_id, status)
        SELECT md5($1 || e.student_id || random()::text), $1, e.student_id, 'absent'
        FROM enrollments e
        WHERE e.course_id = $2
        ON CONFLICT (session_id, student_id) DO NOTHING
      `,
      [session.id, session.course_id],
    );

    await client.query('COMMIT');

    const startedSession = {
      ...updated.rows[0],
      course_code: session.course_code,
      course_title: session.course_title,
    };

    const currentView = publicSessionView(startedSession, now);
    json(res, 200, {
      session: currentView,
      currentCode: currentView.code,
      codeExpiresAt: codeExpiry(now, startedSession.started_at),
    });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function endSession(user, res, sessionId) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const result = await pool.query(
    `
      UPDATE sessions
      SET status = 'ended', ended_at = NOW()
      WHERE id = $1 AND lecturer_id = $2 AND status = 'active'
      RETURNING id, course_id, lecturer_id, title, status, started_at, attendance_closes_at, ended_at, code_seed
    `,
    [sessionId, user.id],
  );

  const session = result.rows[0];
  if (!session) {
    sendError(res, 404, 'Active session not found.');
    return;
  }

  const courseResult = await pool.query(
    'SELECT code AS course_code, title AS course_title FROM courses WHERE id = $1',
    [session.course_id],
  );

  json(res, 200, {
    session: publicSessionView(
      { ...session, ...courseResult.rows[0] },
      new Date(),
    ),
  });
}

async function currentCode(user, res, sessionId) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const result = await pool.query(
    `
      SELECT s.id, s.course_id, s.title, s.status, s.started_at, s.attendance_closes_at,
             s.ended_at, s.code_seed, c.code AS course_code, c.title AS course_title
      FROM sessions s
      INNER JOIN courses c ON c.id = s.course_id
      WHERE s.id = $1 AND s.lecturer_id = $2 AND s.status = 'active'
    `,
    [sessionId, user.id],
  );

  const session = result.rows[0];
  if (!session) {
    sendError(res, 404, 'Active session not found.');
    return;
  }

  const now = new Date();
  json(res, 200, {
    code: publicSessionView(session, now).code,
    expiresAt: codeExpiry(now, session.started_at),
    session: publicSessionView(session, now),
  });
}

async function checkIn(user, req, res) {
  if (!requireRole(user, res, 'student')) {
    return;
  }

  const body = await readJson(req);
  const sessionId = String(body.sessionId || '').trim();
  const submittedCode = String(body.code || '').trim();

  if (!sessionId || !submittedCode) {
    sendError(res, 400, 'sessionId and code are required.');
    return;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const result = await client.query(
      `
        SELECT s.id, s.course_id, s.title, s.status, s.started_at, s.attendance_closes_at,
               s.ended_at, s.code_seed, c.code AS course_code, c.title AS course_title,
               ar.id AS attendance_id, ar.status AS attendance_status, ar.checked_in_at
        FROM sessions s
        INNER JOIN courses c ON c.id = s.course_id
        INNER JOIN attendance_records ar ON ar.session_id = s.id AND ar.student_id = $2
        WHERE s.id = $1
        FOR UPDATE OF ar
      `,
      [sessionId, user.id],
    );
    const session = result.rows[0];

    if (!session) {
      await client.query('ROLLBACK');
      sendError(res, 404, 'Session not found or student not enrolled.');
      return;
    }

    if (session.status !== 'active') {
      await client.query('ROLLBACK');
      sendError(res, 409, 'Session is not active.');
      return;
    }

    const now = new Date();
    if (new Date(now) > new Date(session.attendance_closes_at)) {
      await client.query('ROLLBACK');
      sendError(res, 409, 'Attendance window is closed.');
      return;
    }

    if (session.attendance_status !== 'absent') {
      await client.query('ROLLBACK');
      sendError(
        res,
        409,
        'Attendance has already been submitted for this session.',
      );
      return;
    }

    const acceptedCodes = acceptedSessionCodes(
      session.code_seed,
      now,
      session.started_at,
    );
    if (!acceptedCodes.includes(submittedCode)) {
      await client.query('ROLLBACK');
      sendError(res, 400, 'Invalid or expired session code.');
      return;
    }

    const networkCheck = verifyCampusNetwork(req, body, config);
    if (!networkCheck.valid) {
      await client.query('ROLLBACK');
      sendError(res, 403, 'Campus Wi-Fi proof failed.', networkCheck);
      return;
    }

    const status = attendanceStatusForCheckIn(
      now,
      session.started_at,
      session.attendance_closes_at,
    );
    const proofJson = JSON.stringify({
      network: networkCheck,
      submittedCode,
      checkedAt: now.toISOString(),
    });

    const updateResult = await client.query(
      `
        UPDATE attendance_records
        SET status = $2,
            checked_in_at = $3,
            proof_json = $4::jsonb
        WHERE id = $1
        RETURNING id, session_id, student_id, status, checked_in_at, proof_json
      `,
      [session.attendance_id, status, now.toISOString(), proofJson],
    );

    await client.query('COMMIT');

    json(res, 200, {
      attendance: updateResult.rows[0],
      session: publicSessionView(session, now),
    });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function overrideAttendance(user, req, res, attendanceId) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const body = await readJson(req);
  const nextStatus = String(body.status || '').trim().toLowerCase();
  const reason = String(body.reason || '').trim();
  const validStatuses = ['present', 'late', 'absent', 'excused', 'invalid'];

  if (!validStatuses.includes(nextStatus)) {
    sendError(res, 400, 'Invalid attendance status.');
    return;
  }

  const result = await pool.query(
    `
      UPDATE attendance_records ar
      SET status = $2,
          override_reason = $3,
          overridden_by = $4,
          overridden_at = NOW()
      FROM sessions s
      WHERE ar.id = $1 AND s.id = ar.session_id AND s.lecturer_id = $4
      RETURNING ar.id, ar.session_id, ar.student_id, ar.status, ar.checked_in_at, ar.override_reason
    `,
    [attendanceId, nextStatus, reason || null, user.id],
  );

  if (!result.rows[0]) {
    sendError(res, 404, 'Attendance record not found.');
    return;
  }

  json(res, 200, { attendance: result.rows[0] });
}

async function fetchLectureRowForUser(user, lectureId) {
  const authCondition =
    user.role === 'lecturer'
      ? 's.lecturer_id = $2'
      : `EXISTS (
          SELECT 1
          FROM enrollments e
          WHERE e.course_id = s.course_id AND e.student_id = $2
        )`;

  const result = await pool.query(
    `
      SELECT lr.id, lr.session_id, lr.file_name, lr.status, lr.transcript_text, lr.source_type,
             lr.error_message, lr.created_at, lr.processed_at,
             s.title AS session_title, s.status AS session_status,
             c.code AS course_code, c.title AS course_title,
             ls.id AS summary_id, ls.summary, ls.key_points, ls.action_items
      FROM lecture_recordings lr
      INNER JOIN sessions s ON s.id = lr.session_id
      INNER JOIN courses c ON c.id = s.course_id
      LEFT JOIN lecture_summaries ls ON ls.recording_id = lr.id
      WHERE lr.id = $1
        AND ${authCondition}
    `,
    [lectureId, user.id],
  );

  return result.rows[0] || null;
}

async function verifyLectureSessionAccess(user, sessionId) {
  const sessionResult = await pool.query(
    `
      SELECT s.id
      FROM sessions s
      WHERE s.id = $1
        AND s.lecturer_id = $2
        AND s.status IN ('active', 'ended')
    `,
    [sessionId, user.id],
  );

  return sessionResult.rows[0] || null;
}

async function createLecture(user, req, res) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const body = await readJson(req);
  const sessionId = String(body.sessionId || '').trim();
  const transcriptText = String(body.transcriptText || '').trim();
  const fileName = String(body.fileName || '').trim() || 'lecture-notes.txt';

  if (!sessionId || !transcriptText) {
    sendError(res, 400, 'sessionId and transcriptText are required.');
    return;
  }

  if (transcriptText.length < 60) {
    sendError(
      res,
      400,
      'Transcript text is too short for a useful summary. Add more lecture detail.',
    );
    return;
  }

  if (!(await verifyLectureSessionAccess(user, sessionId))) {
    sendError(res, 404, 'Session not found.');
    return;
  }

  const lectureId = randomId('lec');
  await pool.query(
    `
      INSERT INTO lecture_recordings (
        id,
        session_id,
        file_name,
        status,
        transcript_text,
        source_type
      )
      VALUES ($1, $2, $3, 'pending', $4, 'text_manual')
    `,
    [lectureId, sessionId, fileName, transcriptText],
  );

  queueLectureProcessing(lectureId);

  const lecture = await fetchLectureRowForUser(user, lectureId);
  json(res, 201, {
    lecture: mapLectureRow(lecture),
  });
}

async function createLectureUpload(user, req, res, url) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  if (!config.groqApiKey) {
    sendError(
      res,
      503,
      'Audio transcription is not configured.',
      'Set GROQ_API_KEY in backend/.env or the process environment first.',
    );
    return;
  }

  const sessionId = String(url.searchParams.get('sessionId') || '').trim();
  if (!sessionId) {
    sendError(res, 400, 'sessionId is required.');
    return;
  }

  if (!(await verifyLectureSessionAccess(user, sessionId))) {
    sendError(res, 404, 'Session not found.');
    return;
  }

  const declaredLength = Number(req.headers['content-length'] || 0);
  if (declaredLength > config.maxUploadBytes) {
    sendError(
      res,
      413,
      `Audio upload exceeded the ${Math.round(config.maxUploadBytes / (1024 * 1024))} MB limit.`,
    );
    return;
  }

  try {
    const fileBytes = await readBinaryRequest(req, config.maxUploadBytes);
    if (fileBytes.length === 0) {
      sendError(res, 400, 'Audio upload was empty.');
      return;
    }

    const requestedName = sanitizeFileName(
      req.headers['x-file-name'],
      'lecture-audio.m4a',
    );
    const mimeType =
      String(req.headers['content-type'] || '').split(';')[0].trim() ||
      'application/octet-stream';
    const lectureId = randomId('lec');
    const storagePath = path.join(
      config.uploadDir,
      `${lectureId}${extensionForUpload(requestedName, mimeType)}`,
    );

    await fs.writeFile(storagePath, fileBytes);

    try {
      await pool.query(
        `
          INSERT INTO lecture_recordings (
            id,
            session_id,
            file_name,
            status,
            source_type,
            storage_path,
            mime_type,
            file_size_bytes
          )
          VALUES ($1, $2, $3, 'pending', 'audio_upload', $4, $5, $6)
        `,
        [
          lectureId,
          sessionId,
          requestedName,
          storagePath,
          mimeType,
          fileBytes.length,
        ],
      );
    } catch (error) {
      await fs.unlink(storagePath).catch(() => {});
      throw error;
    }

    queueLectureProcessing(lectureId, 250);

    const lecture = await fetchLectureRowForUser(user, lectureId);
    json(res, 201, {
      lecture: mapLectureRow(lecture),
    });
  } catch (error) {
    const statusCode = error.statusCode || 500;
    sendError(res, statusCode, error.message || 'Audio upload failed.');
  }
}

async function getLecture(user, res, lectureId) {
  const lecture = await fetchLectureRowForUser(user, lectureId);
  if (!lecture) {
    sendError(res, 404, 'Lecture not found.');
    return;
  }

  json(res, 200, { lecture: mapLectureRow(lecture) });
}

async function sessionReport(user, res, sessionId) {
  if (!requireRole(user, res, 'lecturer')) {
    return;
  }

  const sessionResult = await pool.query(
    `
      SELECT s.id, s.course_id, s.title, s.status, s.started_at, s.attendance_closes_at,
             s.ended_at, s.code_seed, c.code AS course_code, c.title AS course_title
      FROM sessions s
      INNER JOIN courses c ON c.id = s.course_id
      WHERE s.id = $1 AND s.lecturer_id = $2
    `,
    [sessionId, user.id],
  );
  const session = sessionResult.rows[0];

  if (!session) {
    sendError(res, 404, 'Session not found.');
    return;
  }

  const attendanceResult = await pool.query(
    `
      SELECT ar.id, ar.status, ar.checked_in_at, ar.override_reason,
             u.id AS student_id, u.name AS student_name, u.email AS student_email
      FROM attendance_records ar
      INNER JOIN users u ON u.id = ar.student_id
      WHERE ar.session_id = $1
      ORDER BY u.name
    `,
    [sessionId],
  );

  const counts = attendanceResult.rows.reduce(
    (summary, row) => {
      summary[row.status] = (summary[row.status] || 0) + 1;
      return summary;
    },
    { present: 0, late: 0, absent: 0, excused: 0, invalid: 0 },
  );

  json(res, 200, {
    session: publicSessionView(session, new Date()),
    counts,
    records: attendanceResult.rows.map((row) => ({
      id: row.id,
      studentId: row.student_id,
      studentName: row.student_name,
      studentEmail: row.student_email,
      status: row.status,
      checkedInAt: row.checked_in_at,
      overrideReason: row.override_reason,
    })),
  });
}

async function requestHandler(req, res) {
  if (req.method === 'OPTIONS') {
    json(res, 204, {});
    return;
  }

  const url = new URL(req.url, 'http://localhost');
  const segments = url.pathname.split('/').filter(Boolean);

  try {
    if (req.method === 'GET' && url.pathname === '/healthz') {
      json(res, 200, { ok: true, groqConfigured: Boolean(config.groqApiKey) });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/auth/login') {
      await handleLogin(req, res);
      return;
    }

    const user = await authenticate(req);
    if (!user) {
      sendError(res, 401, 'Unauthorized');
      return;
    }

    if (req.method === 'GET' && url.pathname === '/me') {
      json(res, 200, { user });
      return;
    }

    if (req.method === 'GET' && url.pathname === '/courses') {
      json(res, 200, { courses: await listCourses(user) });
      return;
    }

    if (req.method === 'GET' && url.pathname === '/sessions') {
      json(res, 200, { sessions: await fetchSessions(user) });
      return;
    }

    if (req.method === 'GET' && url.pathname === '/sessions/active') {
      json(res, 200, { sessions: await fetchSessions(user, { activeOnly: true }) });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/sessions') {
      await createSession(user, req, res);
      return;
    }

    if (req.method === 'POST' && segments[0] === 'sessions' && segments[2] === 'start') {
      await startSession(user, res, segments[1]);
      return;
    }

    if (req.method === 'POST' && segments[0] === 'sessions' && segments[2] === 'end') {
      await endSession(user, res, segments[1]);
      return;
    }

    if (req.method === 'GET' && segments[0] === 'sessions' && segments[2] === 'code') {
      await currentCode(user, res, segments[1]);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/attendance/check-in') {
      await checkIn(user, req, res);
      return;
    }

    if (req.method === 'PATCH' && segments[0] === 'attendance' && segments[1]) {
      await overrideAttendance(user, req, res, segments[1]);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/lectures') {
      await createLecture(user, req, res);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/lectures/upload') {
      await createLectureUpload(user, req, res, url);
      return;
    }

    if (req.method === 'GET' && segments[0] === 'lectures' && segments[1]) {
      await getLecture(user, res, segments[1]);
      return;
    }

    if (
      req.method === 'GET' &&
      segments[0] === 'reports' &&
      segments[1] === 'sessions' &&
      segments[2]
    ) {
      await sessionReport(user, res, segments[2]);
      return;
    }

    sendError(res, 404, 'Route not found.');
  } catch (error) {
    sendError(res, 500, 'Internal server error.', error.message);
  }
}

async function main() {
  await bootstrap();
  const server = http.createServer(requestHandler);
  server.listen(config.port, () => {
    console.log(`attendance-backend listening on http://localhost:${config.port}`);
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
