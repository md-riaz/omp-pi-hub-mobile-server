# OMP/Pi Hub v2 Protocol Notes

The v2 protocol is additive. The unified hub uses canonical `/api/...` routes while mobile mission-control surfaces use event envelopes and richer snapshot fields.

## Compatibility

- Auth uses `Authorization: Bearer <token>`. Query-string tokens are not supported.
- Canonical routes keep their response shape: `/api/register`, `/api/presence`, `/api/event`, `/api/stream`, `/api/snapshot`, `/api/send`, `/api/control`, `/api/poll`.
- New fields are optional for older clients. Unknown fields should be ignored.
- Server normalizes v1 payloads into internal v2 events before applying state changes.
- `GET /api/browse` and `POST /api/send-attachment` have `/api/v2/...` aliases for compatibility.

## Event Envelope

```json
{
  "schemaVersion": 2,
  "id": "evt_01HXZ8RJ9X2ZK3Z4R6W6QF2Q0E",
  "seq": 42,
  "type": "session.presence",
  "sessionId": "session-001",
  "actor": { "kind": "agent", "id": "session-001" },
  "timestamp": 1770000000000,
  "severity": "info",
  "attention": false,
  "payload": { "status": "idle" }
}
```

Fields:

| Field | Required | Notes |
| --- | --- | --- |
| `schemaVersion` | yes | `2` for v2 envelopes. Missing or older payloads are treated as v1. |
| `id` | server | Server assigns `evt_<uuid>` when client omits it. |
| `seq` | server | Monotonic server sequence. |
| `type` | yes | Dot names are preferred for v2, e.g. `session.tool_end`. |
| `sessionId` | optional | Required for session-scoped events. |
| `actor` | optional | `agent`, `operator`, or `server`. |
| `timestamp` | server | Milliseconds since epoch. Server fills missing values. |
| `severity` | optional | `debug`, `info`, `warning`, `error`, `critical`. |
| `attention` | optional | Whether event should create/raise operator attention. |
| `payload` | optional | Event-specific body. |

## Snapshot Shape

`GET /api/snapshot` keeps the v1 `server` and `sessions` shape. v2 adds optional mission-control fields under existing objects.

```json
{
  "server": {
    "pid": 1234,
    "startedAt": 1770000000000,
    "host": "0.0.0.0",
    "port": 18000,
    "time": "2026-02-03T04:05:06.000Z",
    "version": "2.1.0",
    "schemaVersion": 2,
    "availableClis": ["omp", "pi"],
    "staleThresholdMs": 120000,
    "commandTimeoutMs": 300000,
    "capabilities": {
      "schemaVersion": 2,
      "health": true,
      "eventEnvelope": true,
      "commandLifecycle": true,
      "agentCreation": true,
      "browse": true,
      "attachments": true,
      "collaboration": true,
      "summarySnapshot": true,
      "sessionDetail": true
    }
  },
  "sessions": [],
  "commands": []
}
```

## Summary Snapshot and Lazy Thread Detail

Mobile clients should use `GET /api/snapshot/summary` and `GET /api/stream?summary=1` for fast thread-list startup. Summary sessions include only thread-list fields: `id`, `name`, `cwd`, `model`, `pid`, `startedAt`, `lastSeen`, `status`, `online`, `contextUsage`, `health`, and `detailLoaded: false`.

Open a thread with `GET /api/sessions/:sessionId?limit=80`. The response returns the full session metadata plus the most recent history window and paging metadata:

```json
{
  "ok": true,
  "session": {
    "id": "session-001",
    "history": [],
    "historyPage": { "offset": 420, "limit": 80, "total": 500, "hasMore": true },
    "detailLoaded": true
  }
}
```

Pull older messages with `GET /api/sessions/:sessionId/history?before=<offset>&limit=80`. This returns `{ ok, items, offset, limit, total, hasMore }`. This keeps the app behavior messenger-like: list first, recent thread messages on open, older messages only when scrolling upward.

Push devices/notifications are not part of the current canonical server surface.

## Health

Each public session may include derived `health`:

```json
{
  "state": "active",
  "lastSeenAgeMs": 1200,
  "attention": false,
  "attentionReasons": [],
  "runningToolCount": 1,
  "pendingCommandCount": 0,
  "contextPercent": 72
}
```

Health states:

- `offline`: explicit unregister or online flag false.
- `stale`: last presence older than server `staleThresholdMs`.
- `error`: recent tool error, command failure, or agent error event.
- `blocked`: pending approval/diff-style attention.
- `active`: running tool, thinking, or streaming message.
- `idle`: online without attention.
- `unknown`: insufficient data.

## Commands

Commands are queued by mobile/operator routes and delivered by `/api/poll`.

```json
{
  "id": "cmd_01HXZ8RJA1EXAMPLE",
  "sessionId": "session-001",
  "type": "user_message",
  "status": "queued",
  "createdAt": 1770000000000,
  "deliveredAt": null,
  "finishedAt": null,
  "error": null,
  "payload": { "text": "Summarize current status" }
}
```

Statuses: `queued`, `delivered`, `applied`, `failed`, `expired`, `cancelled`.

Current v1 command payloads keep `id`, `type`, `text`, `modelId`, and `timestamp` for extension compatibility.

## Agent Creation

Agent creation is advertised through `capabilities.agentCreation`. Mobile submits a bounded request to `POST /api/agents/create`:

```json
{
  "cli": "pi",
  "cwd": "/home/alice/projects/project-a",
  "name": "project-a-reviewer",
  "model": "gpt-5-codex",
  "initialPrompt": "Review TODOs and report blockers."
}
```

Server resolves `cwd`, requires it to be an existing directory on the hub host, validates `cli` against `config.agentCreation.commands`, and spawns the configured command without shell interpolation. Server must reject arbitrary command strings. If `cli` is omitted, the server uses `config.agentCreation.defaultCli`.

## CLI Availability

`/api/health` and `snapshot().server` include `availableClis`, derived by checking configured command binaries in `config.agentCreation.commands`. The mobile app uses this list to show a CLI picker only when more than one CLI is available.

## Browse Remote Directories

`GET /api/browse?path=/home/user/projects` returns directory listing for the host machine. Requires `browse` capability.

Request query params: `?path=<absolute-path>` defaults to the hub host home directory when omitted. Dot-prefixed entries are hidden by default; pass `showHidden=true` to include them.

Response:

```json
{
  "ok": true,
  "path": "/home/user/projects",
  "parent": "/home/user",
  "root": "/",
  "home": "/home/user",
  "platform": "linux",
  "separator": "/",
  "roots": [{ "name": "/", "path": "/" }],
  "showHidden": false,
  "items": [
    { "name": "project-a", "path": "/home/user/projects/project-a", "type": "directory", "isDirectory": true, "isFile": false, "isSymlink": false, "targetType": null, "extension": "", "size": null, "modifiedAt": 1770000000000, "createdAt": 1769990000000, "permissions": { "readable": true, "writable": true } },
    { "name": "README.md", "path": "/home/user/projects/README.md", "type": "file", "isDirectory": false, "isFile": true, "isSymlink": false, "targetType": null, "extension": ".md", "size": 1024, "modifiedAt": 1770000000000, "createdAt": 1769990000000, "permissions": { "readable": true, "writable": true } }
  ],
  "truncated": false,
  "total": 2,
  "limit": 500
}
```

Server resolves the requested path and rejects invalid or non-directory paths. `roots` gives mobile clients stable root targets across Windows, Linux, and macOS; symlinks keep `type: "symlink"` and expose the resolved `targetType` when available.

## Send Attachment

`POST /api/send-attachment` sends files as attachments to a session. Requires `attachments` capability.

Request body:

```json
{
  "sessionId": "session-001",
  "text": "Describe this image",
  "attachments": [
    { "name": "screenshot.png", "mimeType": "image/png", "data": "<base64>" }
  ]
}
```

Limits: max 5 attachments, images up to 5 MB each, text files up to 100k chars. Only inline images and text/code files are supported; arbitrary binaries are rejected.

Server validates size and type, then queues a command with attachments. Extension converts to content arrays via the active CLI runtime API.

## Representative Event Types

| Type | Payload summary |
| --- | --- |
| `session.registered` | session metadata and optional history |
| `session.presence` | status, model, context usage, available models |
| `session.history` | capped transcript entries |
| `session.tool_start` | tool id/name/args |
| `session.tool_update` | partial tool output |
| `session.tool_end` | result, `isError`, endedAt |
| `command.queued` | command id/type/session id |
| `command.result` | command id/type/applied/error |
