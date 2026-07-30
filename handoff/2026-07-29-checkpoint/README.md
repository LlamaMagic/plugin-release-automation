# Codex Handoff — Plugin Release Automation

Checkpoint date: 2026-07-29
Workspace: `C:\Users\domes\OneDrive\Documentos\GitHub Release Work Flow`

Start by reading, in order:

1. `GITHUB_RELEASE_AUTOMATION_PLAN.md` at the workspace root.
2. `docs/ARTIFACT_CONTRACT.md`.
3. `docs/REQUIRED_CONFIGURATION.md`.
4. This handoff's `STATUS.md`, `VALIDATION.md`, and `NEXT_ACTIONS.md`.

This is a safe checkpoint. The shared automation foundation has been pushed publicly, but no plugin
changes have been pushed, deployed, uploaded to a cloud bucket, released, or sent to the admin
webhook.

## Non-negotiable safety facts

- The webhook secret originally posted in chat is compromised. Never repeat or use it. It must be
  rotated and the replacement entered directly into GitHub.
- The current sample webhook endpoint is plain HTTP. Do not send any replacement secret until
  Kayla provides or confirms HTTPS.
- `PandaFarmerWPF` is beta and must not call the webhook.
- Preserve the exact updater ZIP contracts unless a compatibility change is explicitly approved.
- Do not commit build outputs, credentials, Reactor license material, or generated release ZIPs.
