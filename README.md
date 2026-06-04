# omp-pi-hub-mobile-server

**Version: 2.1.0**

`omp-pi-hub-mobile-server` is a local-first mission-control server and Android app for both Oh-My-Pi (`omp`) and Pi (`pi`) Coding Agent sessions. One shared extension core, one HTTP/SSE server, one token, and one Flutter app show sessions from both CLIs together.

> Status: early but usable. The hub is designed for trusted private networks and should not be exposed directly to the public internet.

## What you get

- Live overview of connected `omp` and `pi` sessions, health, model, context usage, active tools, and recent transcript entries.
- Mobile prompt sending and controls for abort, compact, model switch, shutdown, slash commands, and file attachments.
- Chat-style session detail with user bubbles, assistant bubbles, tool groups, terminal cards, edit cards, and waiting cards.
- A guarded agent creation endpoint that can start either CLI in an existing directory on the hub host.
- CLI availability detection. The app shows an `omp` / `pi` picker only when both binaries are available.
- Bearer-token API auth for all protected routes.
- Memory-only hub state by default: no transcript database and no cloud dependency.

## Architecture

```text
omp sessions                  pi sessions
  |                             |
  | omp-hub.ts wrapper          | pi-hub.ts wrapper
  \------------ hub-core.ts ----/
                  |
                  v
            hub-server.mjs
       token-protected JSON + SSE
                  |
                  v
        apps/omp_hub_app (OMP Pi Hub Mobile)
```

Compatibility shims remain:

```text
omp-hub-server.mjs -> hub-server.mjs
pi-hub-server.mjs  -> hub-server.mjs
```

## Requirements

- Oh-My-Pi Coding Agent `>=0.60.0` and/or Pi Coding Agent `>=0.60.0`.
- Node.js `18+` on the hub host.
- Flutter/Dart if you want to run or build the Android app from source.
- Android device, emulator, or phone on any network route that reaches the hub host.

## Installation

Install from GitHub in either CLI:

```bash
omp install https://github.com/md-riaz/omp-hub-dashboard
pi install https://github.com/md-riaz/omp-hub-dashboard
```

For development:

```bash
git clone https://github.com/md-riaz/omp-hub-dashboard.git
cd omp-hub-dashboard
omp install .
pi install .
```

Restart sessions after install. Extensions load when a session starts, so already-running sessions will not pick up the wrapper until restarted.

## Hub Commands

Inside either CLI session:

```text
/hub info
```

Useful commands:

```text
/hub              # show hub info
/hub start        # start or reconnect to the hub server
/hub info         # show LAN IPs, token, and config path
/hub status       # show server/session status
/hub firewall     # show host firewall hints
/hub stop         # disconnect this session only
/hub server stop  # kill the shared hub server
```

## Connecting From Android

The app needs the hub URL and token.

Shared config path:

```text
~/.hub-dashboard/server/config.json
```

Default server:

```text
0.0.0.0:18000
```

Common URLs:

- Android emulator: `http://10.0.2.2:18000`
- Phone on same WiFi/LAN: `http://<hub-host-lan-ip>:18000`
- Phone over VPN or other network: any IP that reaches the hub host

Run `/hub info` to see detected LAN IPs. Keep the hub on trusted networks and allow inbound TCP `18000` through the host firewall only when needed.

## Mobile App

Run in development:

```bash
cd apps/omp_hub_app
flutter pub get
flutter run
```

Build an APK:

```bash
cd apps/omp_hub_app
flutter build apk --release
```

APK output:

```text
apps/omp_hub_app/build/app/outputs/flutter-apk/app-release.apk
```

## Configuration

The hub creates this config automatically:

```text
~/.hub-dashboard/server/config.json
```

Example:

```json
{
  "enabled": true,
  "host": "0.0.0.0",
  "port": 18000,
  "token": "generated-token",
  "historyLimit": 500,
  "autoStartServer": true,
  "pollIntervalMs": 1500,
  "corsOrigins": [],
  "agentCreation": {
    "commands": {
      "omp": "omp",
      "pi": "pi"
    },
    "defaultCli": "omp",
    "defaultArgs": [],
    "testMode": false
  }
}
```

Key fields:

- `host`: bind address. Defaults to `0.0.0.0` for phone-first LAN/VPN access.
- `port`: hub server port. Defaults to `18000`.
- `token`: bearer token required by the app and API.
- `autoStartServer`: lets either extension wrapper start the shared server automatically.
- `agentCreation.commands`: maps CLI ids (`omp`, `pi`) to binaries or absolute paths.
- `agentCreation.defaultCli`: used when old apps omit `cli`.
- `agentCreation.testMode`: runs spawned commands in foreground test mode.

Restart CLI sessions and the hub server after changing configuration.

## Agent Creation

`POST /api/agents/create` starts a new local process on the hub host in an existing directory. The request may include `cli: "omp"` or `cli: "pi"`. If omitted, the server uses `agentCreation.defaultCli`.

Security model:

- The app chooses only a configured CLI id, not an arbitrary executable.
- The server launches the configured command with `shell: false`.
- Requested working directories are resolved and must already exist.

Bearer-token access can start configured CLIs in any existing directory on the hub host. Keep the hub on trusted paths.

## Manual Server Run

```bash
npm run hub:server
```

Health check:

```bash
curl -H "Authorization: Bearer <token>" "http://127.0.0.1:18000/api/health"
```

`/api/health` and `/api/snapshot` include `availableClis`, which the app uses to decide whether to show the CLI picker.

## API Summary

All API routes except `/` require `Authorization: Bearer <token>`. Query-string tokens are not supported.

- `GET /api/health` - server status, local addresses, capabilities, and available CLIs.
- `GET /api/snapshot` - full session snapshot.
- `GET /api/stream` - SSE snapshot/session update stream.
- `POST /api/register` - register an agent session.
- `POST /api/unregister` - remove a session.
- `POST /api/presence` - update session status/model/context.
- `POST /api/event` - push transcript, tool, and other session events.
- `POST /api/send` - queue a user prompt.
- `POST /api/control` - queue `abort`, `compact`, `set_model`, or `shutdown`.
- `GET /api/poll` - session command polling endpoint.
- `POST /api/agents/create` - guarded agent creation.
- `GET /api/browse` and `GET /api/v2/browse` - list remote directories.
- `POST /api/send-attachment` and `POST /api/v2/send-attachment` - send files as attachments.

## Security Notes

Hub Dashboard is intended for trusted network environments. Do not expose it directly to the public internet without HTTPS, stronger authentication, token rotation, rate limiting, and audit controls.

Protect `~/.hub-dashboard/server/config.json`; it contains the bearer token.

## Troubleshooting

- **No sessions visible**: restart CLI sessions after installing the extension, then run `/hub start`.
- **Phone cannot connect**: run `/hub info` and check firewall rules for TCP `18000`.
- **Unauthorized**: copy the current token from `~/.hub-dashboard/server/config.json`.
- **CLI picker missing**: the server detected zero or one configured CLI binary. Check `agentCreation.commands` and `PATH`.
- **Emulator cannot connect**: use `http://10.0.2.2:18000`, not `localhost`.

## Development

```bash
node --check hub-server.mjs
node --check omp-hub-server.mjs
node --check pi-hub-server.mjs
cd apps/omp_hub_app
flutter analyze
flutter test
```

Future AI agents should read:

- [`AGENTS.md`](AGENTS.md)
- [`docs/ai-context.md`](docs/ai-context.md)

## License

MIT. See [LICENSE](LICENSE).
