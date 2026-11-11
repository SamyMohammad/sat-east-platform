// R1c: one realistic student session against the staging Supabase project (docs/05 s7).
//
// Run: k6 run -e SUPABASE_URL=... -e PUBLISHABLE_KEY=... -e TOKENS_FILE=/abs/tokens.json \
//        -e VUS=300 -e DURATION=5m load/k6/student_flow.js
// tokens.json comes from scripts/load/mint_tokens.mjs (one HS256 JWT per load student).
//
// Session: course map -> topic -> practice (answer each question with think time) ->
// homework when the server asks for it -> quiz when the server allows it -> submit.
// Every request is tagged name:<rpc> so thresholds and the summary are per RPC.
import http from 'k6/http';
import { sleep } from 'k6';
import { Counter, Rate } from 'k6/metrics';

const SUPABASE_URL = (__ENV.SUPABASE_URL || '').replace(/\/+$/, '');
const PUBLISHABLE_KEY = __ENV.PUBLISHABLE_KEY || '';
const VUS = Number(__ENV.VUS || 300);
const DURATION = __ENV.DURATION || '5m';
// Demo topic 1 "Linear Equations" (supabase/seeds/demo/00_structure.sql).
const TOPIC_ID = __ENV.TOPIC_ID || '00000000-0000-4000-8de0-000000000011';

const tokens = JSON.parse(open(__ENV.TOKENS_FILE || 'tokens.json'));

// Business errors the product raises on purpose (docs/07 s9). They are 400s from PostgREST with
// the error code as `message`. They are counted, not failed: under load many students will hit
// the per-minute limits, the cooldown after a failed quiz, or an exhausted pool.
const EXPECTED_ERRORS = [
  'rate_limited',
  'pool_exhausted',
  'cooldown_active',
  'review_needed',
  'homework_needed',
  'practice_needed',
  'attempt_closed',
  'deadline_passed',
];

// 200 and 400 are "expected" statuses so http_req_failed counts only 5xx, 401, 403, 404, ...
// A 400 whose message is not in EXPECTED_ERRORS is caught by rpc_unexpected below.
http.setResponseCallback(http.expectedStatuses(200, 400));

const businessErrors = new Counter('business_errors');
const rpcUnexpected = new Rate('rpc_unexpected');

export const options = {
  stages: [
    { duration: '2m', target: VUS },
    { duration: DURATION, target: VUS },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    'http_req_duration{name:get_practice_questions}': ['p(95)<500'],
    'http_req_duration{name:get_topic}': ['p(95)<500'],
    'http_req_duration{name:check_practice_answer}': ['p(95)<500'],
    'http_req_duration{name:submit_attempt}': ['p(95)<1500'],
    http_req_failed: ['rate<0.01'],
    rpc_unexpected: ['rate<0.01'],
    // Always true; they only make k6 record these sub-metrics so the summary can report them.
    'http_req_duration{name:get_course_map}': ['max>=0'],
    'http_req_duration{name:start_quiz}': ['max>=0'],
    'http_req_duration{name:start_homework}': ['max>=0'],
    'http_req_duration{name:save_answer}': ['max>=0'],
    'http_req_duration{name:submit_homework}': ['max>=0'],
  },
};

function rpc(name, args, token, tag) {
  const res = http.post(`${SUPABASE_URL}/rest/v1/rpc/${name}`, JSON.stringify(args), {
    headers: {
      'Content-Type': 'application/json',
      apikey: PUBLISHABLE_KEY,
      Authorization: `Bearer ${token}`,
    },
    tags: { name: tag || name },
  });
  let body = null;
  try {
    body = res.json();
  } catch (_) {
    body = null;
  }
  if (res.status === 200) {
    rpcUnexpected.add(false);
    return { ok: true, body };
  }
  const message = body && typeof body.message === 'string' ? body.message : '';
  if (res.status === 400 && EXPECTED_ERRORS.includes(message)) {
    businessErrors.add(1, { rpc: name, error: message });
    rpcUnexpected.add(false);
  } else {
    rpcUnexpected.add(true);
  }
  return { ok: false, error: message, body };
}

// MCQ: first choice label. SPR (no choices): any non-empty answer; it is graded server side.
function answerFor(question) {
  const choices = (question && question.choices) || [];
  return choices.length > 0 ? choices[0].label : '1';
}

function think(minS, maxS) {
  sleep(minS + Math.random() * (maxS - minS));
}

// save_answer for every question of an attempt (quiz or homework).
function saveAll(attemptId, questions, token) {
  let seq = 0;
  for (const q of questions) {
    seq += 1;
    rpc(
      'save_answer',
      {
        p_attempt_id: attemptId,
        p_question_id: q.id,
        p_answer: answerFor(q),
        p_time_ms: 2000,
        p_marked: false,
        p_eliminated: [],
        p_client_seq: seq,
      },
      token,
    );
    think(1, 3);
  }
}

export default function () {
  const token = tokens[(__VU - 1) % tokens.length];

  rpc('get_course_map', {}, token);
  let topic = rpc('get_topic', { p_topic_id: TOPIC_ID }, token);

  // Practice: respects rate_answer_per_min (30) with 3-8 s think time.
  const practice = rpc('get_practice_questions', { p_topic_id: TOPIC_ID }, token);
  if (practice.ok && practice.body && Array.isArray(practice.body.questions)) {
    for (const q of practice.body.questions) {
      think(3, 8);
      rpc(
        'check_practice_answer',
        {
          p_attempt_id: practice.body.attempt_id,
          p_question_id: q.id,
          p_answer: answerFor(q),
          p_time_ms: 5000,
        },
        token,
      );
    }
  }

  topic = rpc('get_topic', { p_topic_id: TOPIC_ID }, token);
  let quizState = topic.ok && topic.body && topic.body.quiz ? topic.body.quiz.state : null;

  // The quiz is gated behind a submitted homework (start_quiz raises homework_needed). Do it
  // when the server says it is the next step, so quiz start/submit are actually measured.
  if (quizState === 'homework_needed') {
    const hw = rpc('start_homework', { p_topic_id: TOPIC_ID }, token);
    if (hw.ok && hw.body && Array.isArray(hw.body.questions)) {
      saveAll(hw.body.attempt_id, hw.body.questions, token);
      rpc('submit_attempt', { p_attempt_id: hw.body.attempt_id }, token, 'submit_homework');
      topic = rpc('get_topic', { p_topic_id: TOPIC_ID }, token);
      quizState = topic.ok && topic.body && topic.body.quiz ? topic.body.quiz.state : null;
    }
  }

  // Quiz locked, cooling down or waiting for review: skip it without counting an error.
  if (quizState === 'available' || quizState === 'in_progress') {
    const quiz = rpc('start_quiz', { p_topic_id: TOPIC_ID }, token);
    if (quiz.ok && quiz.body && Array.isArray(quiz.body.questions)) {
      saveAll(quiz.body.attempt_id, quiz.body.questions, token);
      rpc('submit_attempt', { p_attempt_id: quiz.body.attempt_id }, token);
    }
  }

  think(1, 3);
}

function fmt(metric, stat) {
  if (!metric || metric.values[stat] === undefined) return 'n/a';
  return metric.values[stat].toFixed(0);
}

export function handleSummary(data) {
  const rpcs = [
    'get_course_map',
    'get_topic',
    'get_practice_questions',
    'check_practice_answer',
    'start_homework',
    'save_answer',
    'submit_homework',
    'start_quiz',
    'submit_attempt',
  ];
  const lines = [
    '## k6 load test (student_flow)',
    '',
    `VUs: ${VUS}, hold: ${DURATION}`,
    '',
    '| RPC | requests | avg ms | p(95) ms | max ms |',
    '| --- | ---: | ---: | ---: | ---: |',
  ];
  for (const name of rpcs) {
    const m = data.metrics[`http_req_duration{name:${name}}`];
    lines.push(
      `| ${name} | ${m && m.values.count !== undefined ? m.values.count : 'n/a'} | ${fmt(m, 'avg')} | ${fmt(m, 'p(95)')} | ${fmt(m, 'max')} |`,
    );
  }
  const failed = data.metrics.http_req_failed;
  const unexpected = data.metrics.rpc_unexpected;
  const business = data.metrics.business_errors;
  lines.push(
    '',
    `http_req_failed rate: ${failed ? (failed.values.rate * 100).toFixed(2) : 'n/a'} %`,
    `unexpected RPC error rate: ${unexpected ? (unexpected.values.rate * 100).toFixed(2) : 'n/a'} %`,
    `business errors (expected, e.g. rate_limited): ${business ? business.values.count : 0}`,
    `total requests: ${data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 'n/a'}`,
  );
  const md = lines.join('\n') + '\n';
  return {
    'summary.json': JSON.stringify(data),
    'summary.md': md,
    stdout: md,
  };
}
