const fs = require('node:fs/promises');

function trimTranscriptForPrompt(text, maxLength = 24000) {
  const normalized = String(text || '').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }

  return `${normalized.slice(0, maxLength).trimEnd()}\n\n[Transcript truncated for summarization.]`;
}

function extractJsonObject(text) {
  const source = String(text || '').trim();
  const firstBrace = source.indexOf('{');
  const lastBrace = source.lastIndexOf('}');

  if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
    throw new Error('Summary model did not return JSON.');
  }

  return source.slice(firstBrace, lastBrace + 1);
}

function normalizeSummaryPayload(payload) {
  const summary = String(payload.summary || '').trim();
  const keyPoints = Array.isArray(payload.keyPoints)
    ? payload.keyPoints
        .map((entry) => String(entry || '').trim())
        .filter(Boolean)
        .slice(0, 5)
    : [];
  const actionItems = Array.isArray(payload.actionItems)
    ? payload.actionItems
        .map((entry) => String(entry || '').trim())
        .filter(Boolean)
        .slice(0, 4)
    : [];

  if (!summary) {
    throw new Error('Summary model returned an empty summary.');
  }

  if (keyPoints.length === 0) {
    throw new Error('Summary model returned no key points.');
  }

  return {
    summary,
    keyPoints,
    actionItems,
  };
}

async function readApiError(response) {
  const text = await response.text();
  if (!text) {
    return `HTTP ${response.status}`;
  }

  try {
    const json = JSON.parse(text);
    return (
      json?.error?.message ||
      json?.error ||
      json?.message ||
      JSON.stringify(json)
    );
  } catch {
    return text;
  }
}

async function transcribeAudioFile({
  apiKey,
  baseUrl,
  model,
  filePath,
  fileName,
  mimeType,
  language,
}) {
  if (!apiKey) {
    throw new Error('Set GROQ_API_KEY to enable audio transcription.');
  }

  const bytes = await fs.readFile(filePath);
  const form = new FormData();
  form.append(
    'file',
    new Blob([bytes], { type: mimeType || 'application/octet-stream' }),
    fileName,
  );
  form.append('model', model);
  form.append('response_format', 'json');
  if (language) {
    form.append('language', language);
  }

  const response = await fetch(`${baseUrl}/audio/transcriptions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: form,
  });

  if (!response.ok) {
    throw new Error(
      `Groq transcription failed: ${await readApiError(response)}`,
    );
  }

  const payload = await response.json();
  const transcriptText = String(payload.text || '').trim();
  if (!transcriptText) {
    throw new Error('Groq returned an empty transcript.');
  }

  return transcriptText;
}

async function summarizeTranscriptWithGroq({
  apiKey,
  baseUrl,
  model,
  transcriptText,
}) {
  if (!apiKey) {
    throw new Error('Set GROQ_API_KEY to enable Groq summarization.');
  }

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      messages: [
        {
          role: 'system',
          content:
            'You summarize university lectures. Return strict JSON with keys summary, keyPoints, and actionItems. summary must be a concise paragraph. keyPoints must be an array of 3 to 5 short strings. actionItems must be an array of 0 to 3 short strings. Do not include markdown or extra text.',
        },
        {
          role: 'user',
          content: `Summarize this lecture transcript for students:\n\n${trimTranscriptForPrompt(transcriptText)}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`Groq summary failed: ${await readApiError(response)}`);
  }

  const payload = await response.json();
  const content = String(
    payload?.choices?.[0]?.message?.content ||
      payload?.output_text ||
      '',
  ).trim();

  return normalizeSummaryPayload(JSON.parse(extractJsonObject(content)));
}

module.exports = {
  summarizeTranscriptWithGroq,
  transcribeAudioFile,
};
