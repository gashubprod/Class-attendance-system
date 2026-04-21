const test = require('node:test');
const assert = require('node:assert/strict');
const {
  acceptedSessionCodes,
  attendanceStatusForCheckIn,
  generateLectureSummary,
  hashPassword,
  sessionCode,
  verifyCampusNetwork,
  verifyPassword,
} = require('../src/lib');

test('password hashing verifies the original password', () => {
  const hash = hashPassword('demo1234');
  assert.equal(verifyPassword('demo1234', hash), true);
  assert.equal(verifyPassword('wrong-password', hash), false);
});

test('session codes rotate and previous code remains acceptable briefly', () => {
  const startedAt = new Date('2026-04-20T08:00:00Z');
  const firstMoment = new Date('2026-04-20T08:00:10Z');
  const secondMoment = new Date('2026-04-20T08:00:35Z');
  const firstCode = sessionCode('seed_demo', firstMoment, startedAt);
  const secondCode = sessionCode('seed_demo', secondMoment, startedAt);

  assert.notEqual(firstCode, secondCode);
  assert.deepEqual(acceptedSessionCodes('seed_demo', secondMoment, startedAt), [
    secondCode,
    firstCode,
  ]);
});

test('attendance status becomes late after 20 minutes', () => {
  const startedAt = new Date('2026-04-20T08:00:00Z');
  const closesAt = new Date('2026-04-20T08:40:00Z');

  assert.equal(
    attendanceStatusForCheckIn(new Date('2026-04-20T08:19:59Z'), startedAt, closesAt),
    'present',
  );
  assert.equal(
    attendanceStatusForCheckIn(new Date('2026-04-20T08:20:01Z'), startedAt, closesAt),
    'late',
  );
});

test('campus network verification accepts localhost or approved SSIDs', () => {
  const config = {
    allowedCidrs: ['127.0.0.1/32', '::1/128'],
    allowedSsids: ['Wapi-Guest'],
  };

  const viaLoopback = verifyCampusNetwork(
    { headers: {}, socket: { remoteAddress: '::1' } },
    {},
    config,
  );
  assert.equal(viaLoopback.valid, true);

  const viaSsid = verifyCampusNetwork(
    { headers: {}, socket: { remoteAddress: '10.1.1.22' } },
    { network: { ssid: 'Wapi-Guest' } },
    config,
  );
  assert.equal(viaSsid.valid, true);

  const rejected = verifyCampusNetwork(
    { headers: {}, socket: { remoteAddress: '10.1.1.22' } },
    { network: { ssid: 'GuestWifi' } },
    config,
  );
  assert.equal(rejected.valid, false);
});

test('lecture summary generation extracts summary, key points, and action items', () => {
  const transcript = `
    We reviewed the attendance workflow for lecturers and students.
    The backend keeps the attendance API fast by handling lecture summaries asynchronously.
    Students should review the summary before the next class and prepare one question.
  `;

  const result = generateLectureSummary(transcript);

  assert.match(result.summary, /attendance workflow/i);
  assert.ok(result.keyPoints.length >= 2);
  assert.ok(result.actionItems.length >= 1);
});
