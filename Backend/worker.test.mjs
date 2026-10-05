import test from "node:test";
import assert from "node:assert/strict";
import worker from "./worker.mjs";

const env = { GEMINI_API_KEY: "fake-key-for-tests", CLIENT_TOKEN: "test-token-that-is-at-least-32-characters" };
const payload = { text: "오늘 뭐 했어?", sourceLanguage: "ko", targetLanguage: "it", tone: "casual" };
const request = (body = payload, token = env.CLIENT_TOKEN) => new Request("https://test.invalid/translate", {
  method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: JSON.stringify(body)
});

test("reject missing configuration, unauthorized and invalid input without upstream requests", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = () => { throw new Error("Should not call upstream"); };
  try {
    assert.equal((await worker.fetch(request(), {})).status, 503);
    assert.equal((await worker.fetch(request(payload, "wrong"), env)).status, 401);
    for (const body of [null, [], { ...payload, text: "" }, { ...payload, text: "a".repeat(1001) }, { ...payload, targetLanguage: "__proto__" }, { ...payload, tone: "other" }]) {
      assert.equal((await worker.fetch(request(body), env)).status, 400);
    }
    assert.equal((await worker.fetch(request({ ...payload, text: "a".repeat(9000) }), env)).status, 413);
  } finally { globalThis.fetch = original; }
});

test("forward languages and tone, return only completed translation, never retry", async () => {
  const original = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async (url, options) => {
    calls++;
    assert.match(url, /gemini-3\.5-flash-lite:generateContent$/);
    assert.equal(options.headers["x-goog-api-key"], env.GEMINI_API_KEY);
    const body = JSON.parse(options.body);
    assert.equal(body.contents[0].parts[0].text, payload.text);
    assert.match(body.systemInstruction.parts[0].text, /Korean to Italian/);
    assert.match(body.systemInstruction.parts[0].text, /respectful/);
    return Response.json({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: "hidden", thought: true }, { text: "Che cosa ha fatto oggi?" }] } }] });
  };
  try {
    const result = await worker.fetch(request({ ...payload, tone: "formal" }), env);
    assert.deepEqual(await result.json(), { translation: "Che cosa ha fatto oggi?" });
    assert.equal(calls, 1);
    globalThis.fetch = async () => { calls++; return new Response("private diagnostic", { status: 429 }); };
    const limited = await worker.fetch(request(), env);
    assert.equal(limited.status, 429);
    assert.equal(calls, 2);
    assert.equal(JSON.stringify(await limited.json()).includes("private diagnostic"), false);
    globalThis.fetch = async () => Response.json({ candidates: [{ finishReason: "MAX_TOKENS", content: { parts: [{ text: "unfinished" }] } }] });
    assert.equal((await worker.fetch(request(), env)).status, 502);
  } finally { globalThis.fetch = original; }
});
