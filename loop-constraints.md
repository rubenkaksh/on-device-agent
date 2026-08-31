# Loop Constraints

> Binding rules for the autonomous executor. The agent MUST follow these.

## Push & Merge
- Never push to main without human approval
- Always create a draft PR first; let the human review before marking ready
- Commit to a NEW feature branch — never commit directly to main

## Paths
- Never edit .env, .env.*, auth/, payments/, secrets/, credentials/
- Work only inside the declared scope of the card — never wander

## Code
- Always run `flutter analyze` before proposing done
- Never disable tests to make CI green
- Never refactor unrelated code — one task per run
- Max 3 fix attempts per item; escalate after

## Flutter-Specific
- No null force operators (`!`) or force casts (`as T`)
- Use `?.` / `??` / pattern matching for null safety
- Check dependency constraints before `flutter pub add`
- Targeted tests during development; full suite before commit

## Communication
- Tell the human what you're about to do before doing it
- Never close an issue or PR without human approval

## Budget
- If token spend hits 80% of daily cap, switch to report-only
- If loop-pause-all is active in STATE.md or docs/tasklog.md, exit immediately
