# Production container loop

- Discovery: the hosting platform starts or restarts one container from the repository Dockerfile.
- Handoff: the container entrypoint starts the existing Vibe AStock remote-mode supervisor; it does not create a second scheduler or research loop.
- Validation: deployment is accepted only after the image builds, the public page opens through the access gate, `/api` health succeeds through the UI proxy, and the persistent configuration plus access token survive a restart.
- Persistence: `VRA_DATA_ROOT` defaults to `/data`. Production must mount a durable volume at `/data`; deploying without a volume is rejected operationally even if the process starts.
- Scheduling: the existing product scheduler remains authoritative. The platform only restarts failed containers; retry and research budgets remain the repository defaults.

Human checkpoints:

- Creating a paid hosting resource or volume requires the account owner to approve the platform plan.
- `VRA_ACCESS_TOKEN` and model API credentials are secrets: never commit them and only share access links privately with the intended user.
- Do not replace the current production alias until the new deployment passes page, API, and persistence checks.
