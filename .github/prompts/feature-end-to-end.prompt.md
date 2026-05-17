---
name: "Feature End To End"
description: "Implement a full feature across backend, frontend, and optionally database, following this repository's architecture and validation expectations."
agent: "agent"
argument-hint: "Describe the feature, affected screens/endpoints, and acceptance criteria"
---
Implement the requested feature end to end in this repository.

Requirements:
- Inspect existing architecture before changing code.
- Keep backend layering explicit.
- Keep frontend state and UX readable.
- If contracts change, update both sides consistently.
- Validate the changed areas with focused checks.

Return:
- What changed
- Any contract or migration impact
- What was validated