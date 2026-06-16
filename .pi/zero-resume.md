# ZERO Pi Resume

> Local handoff note. It may contain conversation context; keep `.pi/` out of commits.

## Restore

Exact command:

```powershell
pi --session 'C:\Users\vm_user\.pi\agent\sessions\--C--Users-vm_user-Downloads-omp-pi-hub-mobile-server--\2026-06-04T13-15-06-213Z_019e92c5-f065-709b-8369-355f4f6d2069.jsonl'
```

Same session by id:

```powershell
pi --session 019e92c5-f065-709b-8369-355f4f6d2069
```

Open the interactive picker:

```powershell
pi --resume
```

## Session

- Updated: 2026-06-04T13:17:25.358Z
- Shutdown reason: quit
- CWD: C:\Users\vm_user\Downloads\omp-pi-hub-mobile-server
- Session file: C:\Users\vm_user\.pi\agent\sessions\--C--Users-vm_user-Downloads-omp-pi-hub-mobile-server--\2026-06-04T13-15-06-213Z_019e92c5-f065-709b-8369-355f4f6d2069.jsonl
- Session id: 019e92c5-f065-709b-8369-355f4f6d2069

## Conversation Tail

### User - 2026-06-04T13:17:01.140Z

plugins

### Assistant - 2026-06-04T13:17:14.986Z

What about plugins?

Options:
- list available plugins/tools
- inspect project plugins
- add plugin
- fix plugin issue
- explain plugin system

### User - 2026-06-04T13:17:14.999Z

list

### Assistant - 2026-06-04T13:17:25.206Z

Available plugins/tools:

- `lean_ctx` — repo/code context helpers
- `ctx_read`, `ctx_grep`, `ctx_find`, `ctx_ls` — read/search files
- `ctx_shell`, `ctx_execute` — run commands/code
- `todo` — task tracking
- `Agent` — launch subagents
- `web_search`, `web_fetch` — web lookup
- `memory_search`, `memory_remember` — persistent memory
- `specdocs_validate`, `specdocs_format` — PRD/ADR/plan docs
- `intercom` — message other Pi sessions
- `preview_export` — export markdown/LaTeX
- `deepwiki` — query GitHub repo docs/code

Want project plugin files too?

## Continue Prompt

Continue from this ZERO Pi resume. If you need the full context, run the restore command above first.

