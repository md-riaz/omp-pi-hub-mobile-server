# AI Context Reference

Use this alongside `AGENTS.md` when a new AI agent starts work on `omp-pi-hub-mobile-server`.

## One-Screen Summary

`omp-pi-hub-mobile-server` = shared OMP/Pi extension core + local Node hub server + Flutter Android companion app.

- `hub-core.ts` bridges a live `omp` or `pi` session to the hub through thin wrappers.
- `hub-server.mjs` stores live state in memory and exposes HTTP/SSE API.
- `apps/hub_server_app` connects to the server, watches SSE, and sends commands.

The product is for controlling many OMP and Pi agents from a phone. It is not a hosted SaaS. It is a trusted-network tool.

## Why Major Decisions Exist

### One shared server on `0.0.0.0:18000`

Reason: both CLIs should register to the same URL/token so one app can show all sessions. Binding all interfaces supports phone-first LAN/VPN use. Use `host: "127.0.0.1"` for local-only access. HTTP keeps trusted-network setup simple; Android cleartext is enabled for hub connections.

### Neutral config path

Runtime config and token are in `~/.hub-dashboard/server/config.json`. This avoids per-CLI config splits and keeps one server, one port, and one token.

### Memory-only hub state

Reason: user wants live mission control, not a transcript database. Old/stale agents should disappear. Persisting session history would reintroduce stale clutter.

### Bearer token auth

Reason: enough for trusted LAN/VPN use. App and extension use `Authorization: Bearer <token>` for every protected request, including SSE and browse/attachment routes. Query-string tokens are not supported.

### CLI availability detection

Server reports `availableClis` in `/api/health` and `/api/snapshot`. The mobile New Session sheet shows a CLI picker only when more than one configured CLI binary is available; otherwise it silently uses the single available CLI or omits `cli` for older/unknown servers.

### `/hub stop` vs `/hub server stop`

- `/hub stop` unregisters the current session only.
- `/hub server stop` kills the shared server for all sessions.

### No `/hub token`

Reason: `/hub info` already shows token; a separate token command created confusion.

## What To Read First For Common Tasks

Change hub command behavior:

1. `hub-core.ts` command registration near bottom.
2. `networkHint()` / `firewallHint()`.
3. `disconnectSession()`.

Change server session lifecycle:

1. `hub-server.mjs` `removeSessionState()`.
2. `pruneStaleSessions()`.
3. `/api/register`, `/api/unregister`, `/api/presence` routes.
4. `snapshot()`.

Change agent creation:

1. `hub-server.mjs` `normalizeAgentCreationConfig()`.
2. `validateAgentCreationRequest()`.
3. `startAgentCreation()`.
4. `apps/hub_server_app/lib/src/widgets/new_session_sheet.dart`.
5. `apps/hub_server_app/lib/src/hub_client.dart` `AgentCreateRequest`.

Change mobile session list/navigation:

1. `apps/hub_server_app/lib/main.dart` selected/detail session state.
2. `apps/hub_server_app/lib/src/screens/mission_control_screen.dart` narrow vs wide layout.

Change detail transcript UI:

1. `apps/hub_server_app/lib/src/screens/session_detail_screen.dart`.
2. `HubItem` model in `apps/hub_server_app/lib/src/hub_models.dart`.

## Validation Checklist Before Commit

Server/extension:

```bash
node --check hub-server.mjs
node --check omp-hub-server.mjs
node --check pi-hub-server.mjs
```

Flutter:

```bash
cd apps/hub_server_app
flutter analyze
flutter test
flutter build apk --release
```

Local server smoke test:

- Start `node hub-server.mjs` with a temporary `HUB_DASHBOARD_DIR`.
- Set `agentCreation.commands` to known-present binaries such as `node`.
- Confirm `/api/health` returns `availableClis`.

## Current Known Operational Notes

- After updating server code, restart the running Node server: `/hub server stop`, then `/hub start`.
- Release APK is attached to GitHub releases, not committed to repo.
- If user lacks firewall/provider control, use VPN/Tailscale, reverse tunnel/relay, or host with inbound access. Changing port does not bypass firewall requirements.
