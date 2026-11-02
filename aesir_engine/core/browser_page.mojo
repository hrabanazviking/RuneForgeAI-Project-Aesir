"""Server browser page: the minimal try-it chat page the
server serves itself (Janas road J-108).

The roadmap text: "Server: the browser page. A minimal
try-it chat page served by the server itself (Janas
ships one); built under the Cyber-Viking design law, no
framework weight, the page is a tool not a product."
J-099's census row T15 found the surface ABSENT (no
text/html anywhere in the tree; the server served no
page) and its section 3 pre-registered this slice's
shape, including the Origin exception that "lands with
T16's discipline".

This module is the pure layer, in the road's established
shape (pure logic, unit-tested at the lightest target;
the hosts execute the decisions; no socket or session
lives here):

- THE ROUTE. is_browser_page_request(method, path) is
  true iff GET + "/" exactly. One route, no alias
  (answered-locally in the J-108 doc section 8).
- THE DOCUMENT. browser_page_html() is the whole page
  as one compile-time constant string: a single
  self-contained HTML document, inline style and inline
  script, zero external references (no http:// or
  https:// string occurs anywhere in it), no model
  name, no key, no user data baked in. It learns the
  model from GET /v1/models at runtime and holds the
  conversation in page memory only. It calls only the
  J-106-audited chat shape (model, messages, stream,
  stream_options.include_usage) and speaks J-107's
  stream vocabulary (the prefill_progress extension
  event, the usage chunk, [DONE]). Server errors are
  rendered verbatim in the status line, never hidden.
  Transcript text is inserted with textContent only --
  the document contains no innerHTML at all, so neither
  the operator's text nor the model's can become
  markup. Design-law numbers, stated as tests: body
  text 16px, every control at least 44px tall, status
  always in words (never colour alone), the single
  accent colour marks the one primary action (Send),
  no runes and no ornament (ornament would have no
  measurable job on a tool page).
- THE ORIGIN DISCIPLINE (T16, per the J-108 protocol
  section 0.2). Browsers send Origin / Referer /
  Sec-Fetch-Site headers that non-browser clients never
  send; the head layer refused all three at any value,
  which made any browser use impossible. The rules here
  refuse by VALUE, not by presence: an Origin is
  allowed iff it is exactly the serving origin
  (http://127.0.0.1:<port> or http://localhost:<port>);
  a Referer iff it is that origin or under it; a
  Sec-Fetch-Site iff it states same-origin or none.
  Cross-site values -- including another loopback port
  (same-site) -- stay refused, exactly as before.
  Absent headers (every non-browser client) are
  unaffected.

HOST CONTRACT. server/local_protocol.mojo's
LocalHTTPHead executes the origin discipline: the three
browser-header checks call the rules below with the
serving port, and the Bearer check skips exactly the
page request (a browser navigation cannot present a
Bearer header; the page is a constant with no secrets,
the Host check still applies to it, and every data
route keeps the Bearer rule -- the J-108 protocol
section 0.2 records the decision and its price).
cli/native_serve.mojo's serve_loaded answers the page
request with status 200, this document, and
browser_page_content_type(), in both modes (the chat
route the page calls exists in both). J-106's audit
(core/openai_audit.mojo) lists GET / among the served
routes from this slice. This module executes nothing,
opens no device, and contains no speed; any live
browser leg is graded under the road's honesty rules
and is deferred with its recipe in the J-108 doc
section 5, re-cited at the J-118 gate.
"""


def browser_page_content_type() -> String:
    return String("text/html; charset=utf-8")


def is_browser_page_request(method: String, path: String) -> Bool:
    """The page's one route: GET / exactly. No alias --
    /chat, /index.html, and // are strangers and keep
    the standing dispositions."""
    return method == "GET" and path == "/"


def _serving_origins(port: Int) -> List[String]:
    var origins = List[String]()
    origins.append(String("http://127.0.0.1:") + String(port))
    origins.append(String("http://localhost:") + String(port))
    return origins^


def browser_origin_allowed(origin: String, port: Int) -> Bool:
    """An Origin header is allowed iff it is exactly the
    serving origin, in either loopback spelling, at the
    serving port. Any other value -- another site,
    another port, a bare host -- is refused."""
    for allowed in _serving_origins(port):
        if origin == allowed:
            return True
    return False


def browser_referer_allowed(referer: String, port: Int) -> Bool:
    """A Referer header is allowed iff it is the serving
    origin or a URL under it (the page's own fetches
    refer from the page's URL: the origin + "/")."""
    for allowed in _serving_origins(port):
        if referer == allowed or referer.startswith(allowed + "/"):
            return True
    return False


def browser_fetch_site_allowed(value: String) -> Bool:
    """A Sec-Fetch-Site header is allowed iff it states
    same-origin (a fetch from the served page) or none
    (a direct navigation). same-site -- which is what a
    page on another loopback port sends -- and
    cross-site stay refused."""
    return value == "same-origin" or value == "none"


def browser_page_html() -> String:
    """The whole try-it page as one constant document.
    The text carries no backslash anywhere, so what is
    written here is byte-for-byte what is served."""
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Aesir — try-it chat</title>
<link rel="icon" href="data:,">
<style>
* { box-sizing: border-box; }
body { margin: 0; background: #14161a; color: #e8e6e1;
  font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  font-size: 16px; line-height: 1.5; }
main { max-width: 52rem; margin: 0 auto; padding: 1rem; }
h1 { font-size: 1.4rem; margin: 0.5rem 0 0.25rem;
  padding-bottom: 0.4rem; border-bottom: 2px solid #3a3f47; }
.sub { margin: 0.25rem 0 1rem; color: #b9bcc2; }
#status { min-height: 1.5em; margin: 0.5rem 0; font-weight: 600; }
#log { display: block; margin: 0 0 1rem; }
.msg { background: #1d2026; border: 1px solid #3a3f47;
  border-radius: 6px; padding: 0.6rem 0.8rem; margin: 0 0 0.6rem; }
.msg .who { font-weight: 700; margin: 0 0 0.2rem; }
.msg .text { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; }
label { display: block; font-weight: 600; margin: 0.8rem 0 0.3rem; }
input[type="text"], input[type="password"], textarea {
  width: 100%; min-height: 44px; padding: 0.55rem 0.7rem;
  background: #101216; color: #e8e6e1; font-size: 16px;
  border: 1px solid #3a3f47; border-radius: 6px; }
textarea { min-height: 6rem; }
.row { display: flex; flex-wrap: wrap; gap: 0.6rem;
  align-items: center; margin-top: 1rem; }
button { min-height: 44px; min-width: 44px; padding: 0.6rem 1.2rem;
  font-size: 16px; font-weight: 700; color: #e8e6e1;
  background: #262a31; border: 1px solid #4a5058; border-radius: 6px;
  cursor: pointer; }
#send { background: #d9a441; border-color: #d9a441; color: #14161a; }
button:focus-visible, input:focus-visible, textarea:focus-visible {
  outline: 3px solid #d9a441; outline-offset: 2px; }
.check { display: flex; align-items: center; gap: 0.5rem;
  font-weight: 600; }
.check input { width: 24px; height: 24px; }
.hint { color: #b9bcc2; font-size: 0.9rem; margin-top: 0.8rem; }
</style>
</head>
<body>
<main>
<h1>Aesir — try-it chat</h1>
<p class="sub">A minimal test page served by the Aesir server itself.
It talks only to this server's own chat API.</p>
<p id="status" role="status">Ready.</p>
<div id="log" aria-live="polite"></div>
<label for="model">Model</label>
<input type="text" id="model" autocomplete="off"
  placeholder="Model name (Load models fills this in)">
<label for="key">API key (native mode; leave empty in Ollama mode)</label>
<input type="password" id="key" autocomplete="off"
  placeholder="Paste the service key if the server asks for one">
<label for="input">Message</label>
<textarea id="input" rows="4"
  placeholder="Type a message to the model"></textarea>
<div class="row">
<button type="button" id="send">Send</button>
<button type="button" id="models">Load models</button>
<button type="button" id="clear">Clear</button>
<label class="check"><input type="checkbox" id="stream" checked>
Stream the answer</label>
</div>
<p class="hint">Send calls POST /v1/chat/completions on this origin
only. The key stays in this page's memory and is sent only to this
server. Clear empties this page's transcript; it sends nothing.</p>
</main>
<script>
"use strict";
var NL = String.fromCharCode(10);
var history = [];
var statusEl = document.getElementById("status");
var logEl = document.getElementById("log");
var modelEl = document.getElementById("model");
var keyEl = document.getElementById("key");
var inputEl = document.getElementById("input");
var streamEl = document.getElementById("stream");
function setStatus(text) { statusEl.textContent = text; }
function authHeaders() {
  var h = {};
  var k = keyEl.value;
  if (k) { h["Authorization"] = "Bearer " + k; }
  return h;
}
function addMessage(who, text) {
  var box = document.createElement("div");
  box.className = "msg";
  var w = document.createElement("p");
  w.className = "who";
  w.textContent = who;
  var t = document.createElement("p");
  t.className = "text";
  t.textContent = text;
  box.appendChild(w);
  box.appendChild(t);
  logEl.appendChild(box);
  return t;
}
function errText(prefix, message) {
  setStatus("Error: " + prefix + (message ? " — " + message : ""));
}
function loadModels() {
  setStatus("Loading the model list…");
  fetch("/v1/models", { headers: authHeaders() }).then(function (r) {
    return r.json().then(function (body) {
      if (!r.ok) {
        var m = body && body.error ? body.error.message : "";
        errText("the model list was refused (HTTP " + r.status + ")", m);
        return;
      }
      if (body.data && body.data.length > 0) {
        modelEl.value = body.data[0].id;
        setStatus("Ready. Model: " + body.data[0].id);
      } else {
        setStatus("Ready. The server listed no models; type a name.");
      }
    });
  }).catch(function (e) {
    errText("the model list could not be loaded", String(e));
  });
}
function handleEvent(obj, answerEl, state) {
  if (!obj) { return; }
  if (obj.event === "prefill_progress") {
    setStatus("Reading the prompt: " + obj.percent + "%");
    return;
  }
  if (obj.error) {
    state.error = obj.error.message || "the server reported an error";
    return;
  }
  var ch = obj.choices;
  if (ch && ch.length > 0) {
    var c0 = ch[0];
    if (c0.delta && typeof c0.delta.content === "string") {
      state.text += c0.delta.content;
      answerEl.textContent = state.text;
    }
  }
  if (obj.usage) {
    state.usage = obj.usage;
  }
}
function doneStatus(state) {
  if (state.usage) {
    setStatus("Done — prompt " + state.usage.prompt_tokens +
      " tokens, completion " + state.usage.completion_tokens +
      " tokens.");
  } else {
    setStatus("Done.");
  }
}
function sendStreamed(body, answerEl) {
  var state = { text: "", usage: null, error: "" };
  fetch("/v1/chat/completions", {
    method: "POST",
    headers: Object.assign(
      { "Content-Type": "application/json" }, authHeaders()),
    body: JSON.stringify(body)
  }).then(function (r) {
    if (!r.ok) {
      return r.json().then(function (b) {
        var m = b && b.error ? b.error.message : "";
        errText("the request was refused (HTTP " + r.status + ")", m);
        history.pop();
      });
    }
    var reader = r.body.getReader();
    var decoder = new TextDecoder();
    var buf = "";
    function pump() {
      return reader.read().then(function (res) {
        if (res.done) {
          if (buf.indexOf("data: ") === 0) {
            try {
              handleEvent(JSON.parse(buf.slice(6)), answerEl, state);
            } catch (e) { }
          }
          if (state.error) {
            errText("the stream failed", state.error);
            history.pop();
          } else {
            history.push(
              { role: "assistant", content: state.text });
            doneStatus(state);
          }
          return;
        }
        buf += decoder.decode(res.value, { stream: true });
        var i = buf.indexOf(NL);
        while (i >= 0) {
          var line = buf.slice(0, i);
          buf = buf.slice(i + 1);
          if (line.indexOf("data: ") === 0) {
            var payload = line.slice(6);
            if (payload !== "[DONE]") {
              try {
                handleEvent(JSON.parse(payload), answerEl, state);
              } catch (e) { }
            }
          }
          i = buf.indexOf(NL);
        }
        return pump();
      });
    }
    return pump();
  }).catch(function (e) {
    errText("the request could not be sent", String(e));
    history.pop();
  });
}
function sendPlain(body, answerEl) {
  fetch("/v1/chat/completions", {
    method: "POST",
    headers: Object.assign(
      { "Content-Type": "application/json" }, authHeaders()),
    body: JSON.stringify(body)
  }).then(function (r) {
    return r.json().then(function (b) {
      if (!r.ok) {
        var m = b && b.error ? b.error.message : "";
        errText("the request was refused (HTTP " + r.status + ")", m);
        history.pop();
        return;
      }
      var text = "";
      if (b.choices && b.choices.length > 0 &&
          b.choices[0].message) {
        text = b.choices[0].message.content || "";
      }
      answerEl.textContent = text;
      history.push({ role: "assistant", content: text });
      if (b.usage) {
        setStatus("Done — prompt " + b.usage.prompt_tokens +
          " tokens, completion " + b.usage.completion_tokens +
          " tokens.");
      } else {
        setStatus("Done.");
      }
    });
  }).catch(function (e) {
    errText("the request could not be sent", String(e));
    history.pop();
  });
}
function send() {
  var text = inputEl.value;
  if (!text) { setStatus("Type a message first."); return; }
  var model = modelEl.value;
  if (!model) {
    setStatus("Name a model first (Load models, or type its name).");
    return;
  }
  addMessage("You", text);
  history.push({ role: "user", content: text });
  var answerEl = addMessage("Assistant", "");
  inputEl.value = "";
  setStatus("Sending…");
  var streaming = streamEl.checked;
  var body = { model: model, messages: history, stream: streaming };
  if (streaming) {
    body.stream_options = { include_usage: true };
    sendStreamed(body, answerEl);
  } else {
    sendPlain(body, answerEl);
  }
}
document.getElementById("send").addEventListener("click", send);
document.getElementById("models").addEventListener("click", loadModels);
document.getElementById("clear").addEventListener("click", function () {
  history = [];
  logEl.textContent = "";
  setStatus("Ready. Transcript cleared.");
});
loadModels();
</script>
</body>
</html>
"""
