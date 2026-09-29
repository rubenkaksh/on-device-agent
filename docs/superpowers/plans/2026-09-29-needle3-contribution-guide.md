# Needle 3 contribution guide (2 days)

> **Identification caveat (read first).** "needle3" is identified with **medium confidence** as
> **Needle 3, Cactus Compute's 8-29 MB on-device tool-calling model**, developed in the repo
> `cactus-compute/needle` (Apache-2.0, Python, `pip install cactus-needle`). Nothing in this
> local repo (docs/, lib/, README, pubspec, loop-*.md, CodeGraph) mentions "needle". The link to
> this Flutter project (`flutter_gemma_poc`, Gemma via flutter_gemma) is therefore **not
> established**; the only relation found is topical (both are on-device LLM work). Confirm with
> the requester that this is the intended project before starting.
>
> Candidates found:
> 1. https://github.com/cactus-compute/needle - official, the one this guide follows.
> 2. https://github.com/usserwout/needle3 - repo literally named `needle3`; content matches (1), presumably a copy or fork. Not verified as a fork.
> 3. https://huggingface.co/Cactus-Compute/needle3 - model weights.
> 4. Community: geekgineer/needle-rs (WASM runtime), 47thtechcorner/RayCodes_Needle3 (video repo).
>
> Facts below come from web fetches of the GitHub pages on 2026-09-29. **Every command is
> UNVERIFIED (not run)** unless marked otherwise. No CONTRIBUTING.md exists on `main` (404), so
> PR conventions are not documented upstream; the ones below are conventions to follow, not rules.

## Repo facts
- Layout: `needle/` (core package), `tests/`, `.github/workflows/`, `assets/`. About 326 commits, 10 open issues, 17 open PRs.
- License Apache-2.0 (contributions presumably under the same; no CLA seen).
- No Flutter/Dart support mentioned upstream. Android support is an open question (issue #17).

## Day 1: setup, orientation, pick an issue
1. Fork and clone (unverified):
   `gh repo fork cactus-compute/needle --clone && cd needle`
2. Python env (unverified): `python3 -m venv .venv && source .venv/bin/activate`
3. Install: `pip install -e .` (dev) or `pip install "cactus-needle[train]"` for training deps. Editable install is an assumption; check the README/pyproject.
4. Run tests (unverified; runner assumed pytest): `.venv/bin/pytest tests/ -q`. Check `.github/workflows/` for the real CI command and copy it.
5. Smoke test the CLI (unverified, from README): `needle build --platform macos-arm64` then `./macos-arm64/needle --model needle3.cact --tools tools.json --serve`.
6. Read `needle/` entry points, then the docs at cactuscompute.com (tool design, fine-tuning, `.cact` format).
7. Choose an issue. Open issues seen (2026-09-29), no "good first issue" labels visible:
   - #31 setup script false-positive TPU detection: smallest, likely a bug fix in a setup script. Best first pick.
   - #34 Contrastive head not working: needs debugging, medium.
   - #33 How to reproduce benchmark numbers: docs contribution.
   - #128 RFC MLX training backend, #32 Rust+WASM port, #37 multi-turn tool calling: large, discuss first.
   Comment on the issue to claim it before coding.
8. End of day: reproduce the bug or write the failing test on a branch.

## Day 2: implement, test, PR
1. Branch (convention, not documented upstream): `git switch -c fix/<issue-number>-<slug>`
2. Implement with a test first; keep the diff small and one concern per PR.
3. Run the full suite plus whatever linter CI uses (see workflows).
4. Commit with imperative, conventional-style messages (`fix: ...`); verify against `git log` on upstream.
5. Push to your fork and open the PR: `gh pr create --repo cactus-compute/needle --fill`; reference `Fixes #<n>`, state what you ran.
6. Respond to review; note 17 PRs are already open, so expect slow review.
7. If the requester meant this Flutter project instead, the equivalent commands are `flutter pub get`, `flutter analyze`, `flutter test` (unverified).

## Pitfalls
- Upstream is young and fast-moving (announced 2026-09-17); check `main` again before starting.
- Do not confuse `cactus-compute/needle` with unrelated forks (`ericbernhard/needle`, `tchivs/needle`, `usserwout/needle3`); open PRs against the official repo.
- Needle does not chat; every turn is tool calling or extraction. Do not test it as a chat model.
- Training needs the `[train]` extra and likely accelerators; use small data locally.
- Model weights (`needle3.cact`, safetensors) are large; keep them out of commits.
- Some tests may need network or a model download (assumption).
