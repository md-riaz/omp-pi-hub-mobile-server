import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const root = process.cwd();
const token = "test-token";
const hubDir = await mkdtemp(path.join(tmpdir(), "hub-lazy-"));
const port = 19081;

await mkdir(path.join(hubDir, "server"), { recursive: true });
await writeFile(
  path.join(hubDir, "server", "config.json"),
  JSON.stringify({ host: "127.0.0.1", port, token }, null, 2),
);

const server = spawn(process.execPath, ["hub-server.mjs"], {
  cwd: root,
  env: {
    ...process.env,
    HUB_DASHBOARD_DIR: hubDir,
  },
  stdio: ["ignore", "pipe", "pipe"],
});

async function request(method, route, body) {
  const res = await fetch(`http://127.0.0.1:${port}${route}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(body ? { "content-type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

async function waitForServer() {
  for (let i = 0; i < 80; i += 1) {
    try {
      const res = await request("GET", "/api/health");
      if (res.status === 200) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("server did not start");
}

try {
  await waitForServer();
  const entries = Array.from({ length: 120 }, (_, index) => ({
    id: `item-${index}`,
    kind: index % 2 === 0 ? "user" : "assistant",
    role: index % 2 === 0 ? "user" : "assistant",
    timestamp: 1_000 + index,
    text: `message ${index}`,
  }));
  const register = await request("POST", "/api/register", {
    session: {
      id: "session-a",
      name: "Thread A",
      cwd: "/work/a",
      model: "gpt-test",
      status: "idle",
      online: true,
      availableModels: [{ id: "gpt-test", name: "GPT Test" }],
      slashCommands: [{ name: "/help" }],
      todos: [{ id: "todo-1", subject: "Do it", status: "pending" }],
    },
  });
  assert.equal(register.status, 200);
  const history = await request("POST", "/api/event", {
    sessionId: "session-a",
    event: {
      schemaVersion: 2,
      type: "session.history",
      payload: { entries },
    },
  });
  assert.equal(history.status, 200);
  const summary = await request("GET", "/api/snapshot/summary");
  assert.equal(summary.status, 200);
  assert.equal(summary.json.sessions.length, 1);
  assert.equal(summary.json.sessions[0].id, "session-a");
  assert.equal(summary.json.sessions[0].history, undefined);
  assert.equal(summary.json.sessions[0].availableModels, undefined);
  assert.equal(summary.json.sessions[0].detailLoaded, false);

  const fullSnapshot = await request("GET", "/api/snapshot");
  assert.equal(fullSnapshot.status, 404);

  const v2Browse = await request("GET", "/api/v2/browse");
  assert.equal(v2Browse.status, 404);

  const detail = await request("GET", "/api/sessions/session-a?limit=25");
  assert.equal(detail.status, 200);
  assert.equal(detail.json.session.detailLoaded, true);
  assert.equal(detail.json.session.history.length, 25);
  assert.equal(detail.json.session.history[0].id, "item-95");
  assert.equal(detail.json.session.historyPage.offset, 95);
  assert.equal(detail.json.session.historyPage.total, 120);
  assert.equal(detail.json.session.historyPage.hasMore, true);

  const older = await request(
    "GET",
    "/api/sessions/session-a/history?before=95&limit=25",
  );
  assert.equal(older.status, 200);
  assert.equal(older.json.items.length, 25);
  assert.equal(older.json.items[0].id, "item-70");
  assert.equal(older.json.offset, 70);
  assert.equal(older.json.hasMore, true);
} finally {
  server.kill("SIGTERM");
  await new Promise((resolve) => server.once("exit", resolve));
  await rm(hubDir, { recursive: true, force: true });
}
