const crypto = require('node:crypto');

const ATTENDANCE_CLOSE_MINUTES = 40;
const LATE_AFTER_MINUTES = 20;
const CODE_ROTATION_SECONDS = 30;
const DEFAULT_ACTION_ITEMS = [
  'Review the lecture summary and key points before the next class.',
  'Prepare one question or clarification from today\'s lecture.',
];

function randomId(prefix) {
  return `${prefix}_${crypto.randomUUID().replace(/-/g, '')}`;
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const digest = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${digest}`;
}

function verifyPassword(password, storedHash) {
  const [salt, digest] = storedHash.split(':');
  if (!salt || !digest) {
    return false;
  }

  const candidate = crypto.scryptSync(password, salt, 64);
  const stored = Buffer.from(digest, 'hex');
  return stored.length === candidate.length && crypto.timingSafeEqual(stored, candidate);
}

function createJwt(payload, secret, expiresInSeconds = 60 * 60 * 12) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const issuedAt = Math.floor(Date.now() / 1000);
  const body = { ...payload, iat: issuedAt, exp: issuedAt + expiresInSeconds };
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  const encodedBody = Buffer.from(JSON.stringify(body)).toString('base64url');
  const signingInput = `${encodedHeader}.${encodedBody}`;
  const signature = crypto.createHmac('sha256', secret).update(signingInput).digest('base64url');
  return `${signingInput}.${signature}`;
}

function verifyJwt(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid token format');
  }

  const [encodedHeader, encodedBody, encodedSignature] = parts;
  const signingInput = `${encodedHeader}.${encodedBody}`;
  const expected = crypto.createHmac('sha256', secret).update(signingInput).digest('base64url');
  const expectedBuffer = Buffer.from(expected);
  const providedBuffer = Buffer.from(encodedSignature);

  if (
    expectedBuffer.length !== providedBuffer.length ||
    !crypto.timingSafeEqual(expectedBuffer, providedBuffer)
  ) {
    throw new Error('Invalid token signature');
  }

  const payload = JSON.parse(Buffer.from(encodedBody, 'base64url').toString('utf8'));
  if (typeof payload.exp !== 'number' || payload.exp < Math.floor(Date.now() / 1000)) {
    throw new Error('Token expired');
  }

  return payload;
}

function json(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-File-Name',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
  });
  res.end(JSON.stringify(payload));
}

function sendError(res, statusCode, message, details) {
  json(res, statusCode, { error: message, details });
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {};
  }

  const body = Buffer.concat(chunks).toString('utf8');
  if (!body.trim()) {
    return {};
  }

  return JSON.parse(body);
}

function codeSlot(now, startedAt) {
  const elapsedMs = Math.max(0, new Date(now).getTime() - new Date(startedAt).getTime());
  return Math.floor(elapsedMs / (CODE_ROTATION_SECONDS * 1000));
}

function sessionCode(seed, now, startedAt) {
  const slot = codeSlot(now, startedAt);
  const hash = crypto.createHash('sha256').update(`${seed}:${slot}`).digest('hex');
  const numeric = BigInt(`0x${hash.slice(0, 12)}`) % 1000000n;
  return numeric.toString().padStart(6, '0');
}

function acceptedSessionCodes(seed, now, startedAt) {
  const currentSlot = codeSlot(now, startedAt);
  const slots = currentSlot > 0 ? [currentSlot, currentSlot - 1] : [currentSlot];
  return slots.map((slot) => {
    const hash = crypto.createHash('sha256').update(`${seed}:${slot}`).digest('hex');
    const numeric = BigInt(`0x${hash.slice(0, 12)}`) % 1000000n;
    return numeric.toString().padStart(6, '0');
  });
}

function codeExpiry(now, startedAt) {
  const slot = codeSlot(now, startedAt);
  const started = new Date(startedAt).getTime();
  return new Date(started + (slot + 1) * CODE_ROTATION_SECONDS * 1000);
}

function attendanceStatusForCheckIn(now, startedAt, closesAt) {
  const checkedAt = new Date(now).getTime();
  const start = new Date(startedAt).getTime();
  const close = new Date(closesAt).getTime();

  if (checkedAt > close) {
    return 'invalid';
  }

  const lateBoundary = start + LATE_AFTER_MINUTES * 60 * 1000;
  return checkedAt <= lateBoundary ? 'present' : 'late';
}

function normalizeIp(rawValue) {
  if (!rawValue) {
    return '';
  }

  const first = String(rawValue).split(',')[0].trim();
  return first.startsWith('::ffff:') ? first.slice(7) : first;
}

function parseIpv4(ip) {
  const segments = ip.split('.').map((part) => Number(part));
  if (segments.length !== 4 || segments.some((part) => Number.isNaN(part) || part < 0 || part > 255)) {
    return null;
  }

  return ((segments[0] << 24) >>> 0) + (segments[1] << 16) + (segments[2] << 8) + segments[3];
}

function ipv4InCidr(ip, cidr) {
  const [base, maskString] = cidr.split('/');
  const ipValue = parseIpv4(ip);
  const baseValue = parseIpv4(base);
  const maskBits = Number(maskString);

  if (ipValue === null || baseValue === null || Number.isNaN(maskBits)) {
    return false;
  }

  const mask = maskBits === 0 ? 0 : (0xffffffff << (32 - maskBits)) >>> 0;
  return (ipValue & mask) === (baseValue & mask);
}

function verifyCampusNetwork(req, body, config) {
  const remoteIp = normalizeIp(req.headers['x-forwarded-for'] || req.socket.remoteAddress);
  const providedSsid = body?.network?.ssid?.trim();
  const allowedSsids = config.allowedSsids.map((ssid) => ssid.toLowerCase());
  const matchedSsid = providedSsid && allowedSsids.includes(providedSsid.toLowerCase());
  const matchedIp = config.allowedCidrs.some((cidr) => {
    if (cidr === '::1/128') {
      return remoteIp === '::1';
    }
    return ipv4InCidr(remoteIp, cidr);
  });

  if (matchedIp) {
    return { valid: true, source: 'ip', remoteIp, ssid: providedSsid || null };
  }

  if (matchedSsid) {
    return { valid: true, source: 'ssid', remoteIp, ssid: providedSsid };
  }

  return {
    valid: false,
    source: null,
    remoteIp,
    ssid: providedSsid || null,
    reason: 'Request did not match approved campus Wi-Fi proof.',
  };
}

function normalizeTranscript(text) {
  return String(text || '')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function splitSentences(text) {
  return normalizeTranscript(text)
    .replace(/\n/g, ' ')
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
}

function trimText(text, maxLength = 160) {
  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength - 1).trimEnd()}...`;
}

function extractActionItems(sentences) {
  const actionPattern = /\b(submit|review|prepare|read|implement|complete|build|remember|revise|practice|test|install|bring|draft|finish|update|demo|share)\b/i;
  const actionItems = [];

  for (const sentence of sentences) {
    if (!actionPattern.test(sentence)) {
      continue;
    }

    const cleaned = trimText(sentence.replace(/\s+/g, ' '), 140);
    if (!actionItems.includes(cleaned)) {
      actionItems.push(cleaned);
    }

    if (actionItems.length === 3) {
      break;
    }
  }

  return actionItems.length > 0 ? actionItems : DEFAULT_ACTION_ITEMS;
}

function generateLectureSummary(transcriptText) {
  const normalized = normalizeTranscript(transcriptText);
  if (!normalized) {
    throw new Error('Transcript text is required.');
  }

  const sentences = splitSentences(normalized);
  const fallbackSentences = normalized
    .split(/\n+/)
    .map((part) => part.trim())
    .filter(Boolean);
  const source = sentences.length > 0 ? sentences : fallbackSentences;

  const summary = trimText(source.slice(0, 3).join(' '), 420);
  const keyPoints = source.slice(0, 4).map((sentence) => trimText(sentence, 160));
  const actionItems = extractActionItems(source);

  return {
    transcriptText: normalized,
    summary,
    keyPoints,
    actionItems,
  };
}

function publicSessionView(session, currentTime = new Date()) {
  const code = session.status === 'active' && session.code_seed && session.started_at
    ? sessionCode(session.code_seed, currentTime, session.started_at)
    : null;

  return {
    id: session.id,
    courseId: session.course_id,
    courseCode: session.course_code,
    courseTitle: session.course_title,
    title: session.title,
    status: session.status,
    startedAt: session.started_at,
    attendanceClosesAt: session.attendance_closes_at,
    endedAt: session.ended_at,
    code,
    latestLectureId: session.latest_lecture_id || null,
    latestLectureStatus: session.latest_lecture_status || null,
    latestLectureCreatedAt: session.latest_lecture_created_at || null,
  };
}

module.exports = {
  ATTENDANCE_CLOSE_MINUTES,
  CODE_ROTATION_SECONDS,
  LATE_AFTER_MINUTES,
  acceptedSessionCodes,
  attendanceStatusForCheckIn,
  codeExpiry,
  createJwt,
  generateLectureSummary,
  hashPassword,
  json,
  normalizeTranscript,
  publicSessionView,
  randomId,
  readJson,
  sendError,
  sessionCode,
  verifyCampusNetwork,
  verifyJwt,
  verifyPassword,
};
