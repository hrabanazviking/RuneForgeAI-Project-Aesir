"use strict";
/* J-117 verification for worked example 1 (j117_example_chat_page.html).
 *
 * This check EXECUTES the page's own <script> block — extracted from
 * the filed HTML, never copied — headlessly under Node, with a minimal
 * DOM stub and a fetch stub answering from the filed response
 * artefacts in j117_web_fixtures.json (J-106/J-107 shapes). It drives
 * the page's own handlers: the loadModels() call the page makes at
 * startup, then Send three ways (streamed, plain, refused), then
 * Clear and one more plain send. Every assertion is about what the
 * page actually built, sent, assembled, and displayed.
 *
 * It proves the page's client logic only. No live server was started
 * and no browser engine ran; the live leg is deferred with its recipe
 * in the J-117 doc (section 7), re-cited at the J-118 gate.
 */
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { TextDecoder } from "node:util";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const html = fs.readFileSync(path.join(here, "j117_example_chat_page.html"), "utf8");
const fixtures = JSON.parse(fs.readFileSync(path.join(here, "j117_web_fixtures.json"), "utf8"));

let failures = 0;
let total = 0;
function check(name, cond, detail) {
  total += 1;
  if (cond) {
    console.log("PASS: " + name);
  } else {
    failures += 1;
    console.log("FAIL: " + name + (detail ? " — " + detail : ""));
  }
}

/* ---- page invariants on the document itself ---- */
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
check("page carries exactly one extractable script block", !!scriptMatch && html.indexOf("<script>") === html.lastIndexOf("<script>"));
check("page uses textContent only (no innerHTML anywhere)", !html.includes("innerHTML"));
check("page references no external URL (no scheme string in the document)", !html.includes("http://") && !html.includes("https://"));
check("page is a single self-contained document under the 24576-byte bound", html.length > 2048 && html.length <= 24576, "bytes=" + html.length);
const script = scriptMatch[1];

/* ---- DOM stub ---- */
const statusHistory = [];
function makeEl(id) {
  const el = {
    id: id || "",
    className: "",
    value: "",
    checked: false,
    children: [],
    _handlers: {},
    _text: "",
    appendChild(c) { this.children.push(c); return c; },
    addEventListener(ev, fn) { this._handlers[ev] = fn; },
  };
  Object.defineProperty(el, "textContent", {
    get() { return this._text; },
    set(v) {
      this._text = String(v);
      if (v === "") { this.children = []; }
      if (this.id === "status") { statusHistory.push(this._text); }
    },
  });
  return el;
}
const els = {};
["status", "log", "origin", "model", "key", "input", "stream", "send", "models", "clear"]
  .forEach((id) => { els[id] = makeEl(id); });
els.stream.checked = true;
const documentStub = {
  getElementById(id) { return els[id] || null; },
  createElement() { return makeEl(""); },
};

/* ---- fetch stub over the filed artefacts ---- */
const requests = [];
function sseResponse() {
  const bytes = new TextEncoder().encode(fixtures.sse_stream);
  const cuts = [Math.floor(bytes.length / 3), Math.floor((2 * bytes.length) / 3)];
  const chunks = [bytes.slice(0, cuts[0]), bytes.slice(cuts[0], cuts[1]), bytes.slice(cuts[1])];
  let i = 0;
  return {
    ok: true,
    status: 200,
    json: async () => { throw new Error(" SSE body is not JSON"); },
    body: {
      getReader() {
        return {
          read: async () => (i < chunks.length
            ? { done: false, value: chunks[i++] }
            : { done: true }),
        };
      },
    },
  };
}
function fetchStub(url, options) {
  const opts = options || {};
  const rec = {
    url: String(url),
    method: opts.method || "GET",
    headers: opts.headers || {},
    body: typeof opts.body === "string" ? opts.body : null,
  };
  requests.push(rec);
  if (rec.url.endsWith("/v1/models")) {
    return Promise.resolve({
      ok: true, status: 200,
      json: async () => JSON.parse(JSON.stringify(fixtures.models)),
    });
  }
  if (rec.url.endsWith("/v1/chat/completions")) {
    const sent = JSON.parse(rec.body);
    const last = sent.messages[sent.messages.length - 1].content;
    if (last.includes("refuse me")) {
      return Promise.resolve({
        ok: false, status: fixtures.refusal.status,
        json: async () => JSON.parse(JSON.stringify(fixtures.refusal.body)),
        body: { getReader() { throw new Error("refusal has no stream body"); } },
      });
    }
    if (sent.stream) { return Promise.resolve(sseResponse()); }
    return Promise.resolve({
      ok: true, status: 200,
      json: async () => JSON.parse(JSON.stringify(fixtures.plain_completion)),
    });
  }
  return Promise.reject(new Error("unexpected URL " + rec.url));
}

async function flush(rounds) {
  for (let i = 0; i < (rounds || 60); i++) {
    await new Promise((r) => setImmediate(r));
  }
}
function lastAnswerEl() {
  const log = els.log.children;
  return log[log.length - 1].children[1];
}
function chatRequests() {
  return requests.filter((r) => r.url.endsWith("/v1/chat/completions"));
}

(async () => {
  const context = vm.createContext({
    document: documentStub,
    fetch: fetchStub,
    TextDecoder,
    console,
  });
  vm.runInContext(script, context, { filename: "j117_example_chat_page.html<script>" });
  await flush();

  /* startup: the page's own loadModels() ran */
  check("startup called GET /v1/models exactly once",
    requests.length === 1 && requests[0].method === "GET" && requests[0].url.endsWith("/v1/models"));
  check("model field filled from the filed models shape",
    els.model.value === fixtures.models.data[0].id, "model=" + els.model.value);
  check("status reports the loaded model in words",
    els.status.textContent === "Ready. Model: " + fixtures.models.data[0].id,
    "status=" + els.status.textContent);

  els.key.value = "test-key";

  /* streamed send */
  els.input.value = "stream please";
  els.stream.checked = true;
  els.send._handlers.click();
  await flush();
  let chats = chatRequests();
  check("streamed send issued exactly one chat request", chats.length === 1);
  let sent = JSON.parse(chats[0].body);
  check("streamed request body: model + stream + include_usage, one user message",
    sent.model === fixtures.models.data[0].id && sent.stream === true &&
    sent.stream_options && sent.stream_options.include_usage === true &&
    sent.messages.length === 1 && sent.messages[0].role === "user" &&
    sent.messages[0].content === "stream please",
    chats[0].body);
  check("streamed request carried the typed key as Bearer and JSON content type",
    chats[0].headers.Authorization === "Bearer test-key" &&
    chats[0].headers["Content-Type"] === "application/json",
    JSON.stringify(chats[0].headers));
  check("streamed answer assembled from the content chunks",
    lastAnswerEl().textContent === "Hello, world", "answer=" + lastAnswerEl().textContent);
  check("progress event reached the status line in words",
    statusHistory.includes("Reading the prompt: 50%"),
    "statuses=" + JSON.stringify(statusHistory));
  check("usage chunk rendered as counts in the final status",
    els.status.textContent === "Done — prompt 12 tokens, completion 2 tokens.",
    "status=" + els.status.textContent);

  /* plain send */
  els.input.value = "plain please";
  els.stream.checked = false;
  els.send._handlers.click();
  await flush();
  chats = chatRequests();
  check("plain send issued a second chat request", chats.length === 2);
  sent = JSON.parse(chats[1].body);
  check("plain request body: stream false, no stream_options, full history sent",
    sent.stream === false && !("stream_options" in sent) &&
    sent.messages.length === 3 &&
    sent.messages[1].role === "assistant" &&
    sent.messages[1].content === "Hello, world",
    chats[1].body);
  check("plain answer shown and counted",
    lastAnswerEl().textContent === "Plain answer." &&
    els.status.textContent === "Done — prompt 9 tokens, completion 2 tokens.",
    "answer=" + lastAnswerEl().textContent + " status=" + els.status.textContent);

  /* refused send (streamed path's refusal branch) */
  els.input.value = "refuse me";
  els.stream.checked = true;
  els.send._handlers.click();
  await flush();
  chats = chatRequests();
  check("refused send issued a third chat request", chats.length === 3);
  check("refusal shown verbatim in the status line",
    els.status.textContent ===
      "Error: the request was refused (HTTP 400) — model is not the resident model",
    "status=" + els.status.textContent);

  /* clear, then one more plain send: history must restart */
  els.clear._handlers.click();
  check("clear reports itself and sends nothing",
    els.status.textContent === "Ready. Transcript cleared." && chatRequests().length === 3);
  els.input.value = "after clear";
  els.stream.checked = false;
  els.send._handlers.click();
  await flush();
  chats = chatRequests();
  sent = JSON.parse(chats[3].body);
  check("after clear, the refused turn stayed out and history restarted at one message",
    chats.length === 4 && sent.messages.length === 1 &&
    sent.messages[0].content === "after clear",
    chats[3] ? chats[3].body : "no 4th request");

  console.log(failures === 0
    ? "ALL PASS: web example client logic (" + total + " checks)"
    : "FAILURES: " + failures + " of " + total);
  process.exit(failures === 0 ? 0 : 1);
})().catch((e) => {
  console.log("FAIL: harness error — " + (e && e.stack ? e.stack : String(e)));
  process.exit(1);
});
