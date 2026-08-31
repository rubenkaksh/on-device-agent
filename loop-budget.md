# Loop Budget — on-device-agent

> Flutter on-device LLM workspace.

## Daily limits

| Loop | Max runs/day | Max tokens/day | Max sub-agent spawns/run |
|------|--------------|----------------|--------------------------|
| Autonomous | 4 | 100k | 2 |

## On budget exceed

1. Pause schedulers (disable launchd jobs)
2. Append event to `loop-run-log.md`
3. Notify human

## Kill switch

- Command or issue label: `loop-pause-all`
