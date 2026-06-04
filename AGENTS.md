# AGENTS.md - AI Agent Onboarding Guide

This repo is the unified `omp-pi-hub-mobile-server` project. Read this before editing.

## Project Purpose

`omp-pi-hub-mobile-server` is a local-first mobile mission-control surface for both Oh-My-Pi (`omp`) and Pi (`pi`) Coding Agent sessions.

It has three runtime pieces:

1. `hub-core.ts` plus wrappers `omp-hub.ts` and `pi-hub.ts`.
2. `hub-server.mjs`, with `omp-hub-server.mjs` and `pi-hub-server.mjs` as compatibility shims.
3. `apps/omp_hub_app`, the OMP Pi Hub Mobile Companion Flutter Android app.

Primary user goal: monitor and control many OMP and Pi sessions from Android without RDP, with one URL, one token, and one combined session list.

## Current Product Direction

- App must not require Tailscale. Any LAN, VPN, tunnel, or routed network path can work.
- Direct phone access requires host/provider firewall to allow TCP `18000`.
- Shared config and bearer token live at `~/.hub-dashboard/server/config.json`.
- App remembers URL and token and auto-connects.
- App shows only connected/current sessions; hub should not retain stale disconnected sessions in memory.
- New Session uses server `availableClis`: show a CLI picker only when multiple configured CLI binaries are available.
- `/hub stop` disconnects current session only; `/hub server stop` kills the shared server.
- `/hub info` shows token; do not reintroduce `/hub token`.

## Current Feature State

Implemented:

- Shared extension implementation with CLI-specific wrapper params.
- Shared hub server, default `0.0.0.0:18000`, memory-only state, bearer auth, JSON API, and SSE stream.
- Dual CLI registration from `omp` and `pi` sessions into the same server.
- Server CLI availability detection and guarded agent creation for configured CLI ids.
- Android companion app with connection persistence, auto-connect, mission-control list, session detail, prompt/control sending, file attachments, browse, and New Session CLI selection.
- Stale session pruning from hub memory.
- Terminal-style agent detail view with collapsible tools/commands/output.

Not implemented / paused:

- HTTPS, token rotation, rate limiting, or stronger auth for public exposure.
- Optional cloud relay mode.

## Key Files

Root:

- `README.md` - user setup/use/troubleshooting.
- `package.json` - package manifest for both `omp` and `pi` extension loaders.
- `docs/omp-hub-v2-protocol.md` - API/protocol notes.
- `docs/ai-context.md` - short AI context reference.

Extension:

- `hub-core.ts` - shared extension logic, config loading, auto-start, session register/presence/event streaming, command polling, and `/hub` command family.
- `omp-hub.ts` - OMP wrapper using `@oh-my-pi/pi-coding-agent`, client id `omp-hub-extension`, CLI `omp`.
- `pi-hub.ts` - Pi wrapper using `@earendil-works/pi-coding-agent`, client id `pi-hub-extension`, CLI `pi`.

Server:

- `hub-server.mjs` - shared Node HTTP/SSE server, default `0.0.0.0:18000`.
- `omp-hub-server.mjs` and `pi-hub-server.mjs` - import shims for back compatibility.
- `snapshot()` - returns server info, sessions, commands, and `availableClis`.
- `removeSessionState()` - deletes session, command queues, commands, and broadcasts removal.
- `validateAgentCreationRequest()` / `startAgentCreation()` - validate CLI id/cwd and spawn configured command with `shell: false`.

Flutter Android app:

- `apps/omp_hub_app/lib/main.dart` - connection state, SSE snapshot, new-session flow.
- `apps/omp_hub_app/lib/src/hub_client.dart` - HTTP + SSE client and agent-create request serialization.
- `apps/omp_hub_app/lib/src/hub_models.dart` - API models including `HubServerInfo.availableClis`.
- `apps/omp_hub_app/lib/src/widgets/new_session_sheet.dart` - conditional CLI picker and model/path/prompt inputs.
- `apps/omp_hub_app/android/app/src/main/AndroidManifest.xml` - keep `android:usesCleartextTraffic="true"` while hub uses HTTP.

## API Summary

All routes except `/` require `Authorization: Bearer <token>`. Query-string tokens are not supported.

Core routes:

- `GET /api/health` - server status, addresses, capabilities, and `availableClis`.
- `GET /api/snapshot` - full session snapshot, server info, and commands.
- `GET /api/stream` - SSE stream; emits snapshot/session/command events.
- `POST /api/register`
- `POST /api/unregister`
- `POST /api/presence`
- `POST /api/event`
- `POST /api/send`
- `POST /api/control`
- `GET /api/poll`
- `GET /api/browse` and `GET /api/v2/browse`
- `POST /api/send-attachment` and `POST /api/v2/send-attachment`
- `POST /api/agents/create`

## Agent Creation

Mobile submits `{ cwd, name?, model?, initialPrompt?, cli? }` to `POST /api/agents/create`.

Server behavior:

- Resolves `cwd` and requires an existing directory.
- Validates `cli` against `config.agentCreation.commands`.
- Defaults to `config.agentCreation.defaultCli` when older apps omit `cli`.
- Spawns only the configured command with `shell: false`.
- Provides neutral env vars (`HUB_AGENT_*`) plus `OMP_HUB_*` and `PI_HUB_*` aliases.

## Development Commands

From repo root:

```bash
node --check hub-server.mjs
node --check omp-hub-server.mjs
node --check pi-hub-server.mjs
```

Flutter:

```bash
cd apps/omp_hub_app
flutter analyze
flutter test
flutter build apk --release
```

## Runtime / Troubleshooting

Config path:

```text
~/.hub-dashboard/server/config.json
```

Server PID path:

```text
~/.hub-dashboard/server/server.pid
```

Default server:

```text
0.0.0.0:18000
```

If app cannot connect:

- Verify app uses URL from `/hub info`.
- Verify Android APK has cleartext enabled.
- Verify host is listening on `0.0.0.0:18000`.
- Windows firewall or VPS/provider firewall must allow inbound TCP `18000`.
- Emulator uses `http://10.0.2.2:18000`, not `localhost`.

Admin CMD firewall command:

```cmd
netsh advfirewall firewall add rule name="OMP Pi Hub TCP 18000" dir=in action=allow protocol=TCP localport=18000
```

## Coding Notes

- Keep hub server memory-only unless user explicitly approves persistence.
- Do not allow arbitrary executable strings from mobile clients.
- Do not trust app-provided file uploads; validate size/type server-side.
- If adding public exposure, add HTTPS/auth hardening/rate limit first.
