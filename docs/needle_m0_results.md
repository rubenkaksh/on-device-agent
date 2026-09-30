## Tools/versions

- Python: 3.12.13
- cactus-needle: 3.0.6
- pyelftools: 0.33

## Files per platform

### android-arm64
```
-rw-r--r--  1.6M engines/android-arm64/libneedle.a
-rwxr-xr-x  1.1M engines/android-arm64/needle
-rw-r--r--  1.2K engines/android-arm64/needle.h
-rw-r--r--   33.7M engines/android-arm64/needle3.cact

File types:
engines/android-arm64/libneedle.a: current ar archive
engines/android-arm64/needle: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, BuildID[sha1]=44e7bac5f26975af5838d3dc21f72bee9d864b1f, stripped
engines/android-arm64/needle.h: C source, ASCII text
engines/android-arm64/needle3.cact: data
```

### ios-arm64
```
-rw-r--r--  1.1M engines/ios-arm64/libneedle.a
-rw-r--r--  1.2K engines/ios-arm64/needle.h
-rw-r--r--   33.7M engines/ios-arm64/needle3.cact

File types:
engines/ios-arm64/libneedle.a: current ar archive random library
engines/ios-arm64/needle.h: C source, ASCII text
engines/ios-arm64/needle3.cact: data
```

### ios-sim-arm64
```
-rw-r--r--  1.1M engines/ios-sim-arm64/libneedle.a
-rw-r--r--  1.2K engines/ios-sim-arm64/needle.h
-rw-r--r--   33.7M engines/ios-sim-arm64/needle3.cact

File types:
engines/ios-sim-arm64/libneedle.a: current ar archive random library
engines/ios-sim-arm64/needle.h: C source, ASCII text
engines/ios-sim-arm64/needle3.cact: data
```

### macos-arm64
```
-rw-r--r--  1.1M engines/macos-arm64/libneedle.a
-rwxr-xr-x  805.5K engines/macos-arm64/needle
-rw-r--r--  1.2K engines/macos-arm64/needle.h
-rw-r--r--   33.7M engines/macos-arm64/needle3.cact

File types:
engines/macos-arm64/libneedle.a: current ar archive random library
engines/macos-arm64/needle: Mach-O 64-bit executable arm64
engines/macos-arm64/needle.h: C source, ASCII text
engines/macos-arm64/needle3.cact: data
```

### Byte counts summary
- libneedle.a: android-arm64=1664680, ios-arm64=1137864, ios-sim-arm64=1155504, macos-arm64=1158848
- needle exe: android-arm64=1192864, macos-arm64=824792
- needle.h: 1187 (all platforms identical)
- needle3.cact: 35335380 (all platforms)

## Header

```c
#ifndef NEEDLE_H
#define NEEDLE_H

#ifndef NEEDLE_API
#define NEEDLE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* One process-global, non-thread-safe model. Negative returns indicate failure.
   needle_init returns the tokenized static-prefix length on success. It can fail
   when the system prompt plus statically-declared tools do not fit the model's
   context window; call needle_last_error() for the specific reason. */
NEEDLE_API int needle_init(
    const char* system_prompt,
    const char* tools_json,
    const char* tool_index_path
);

/* Last process-global error, owned by the runtime and valid until the next API call. */
NEEDLE_API const char* needle_last_error(void);

NEEDLE_API int needle_complete(
    const char* input,
    int max_new_tokens,
    char* out,
    int out_capacity
);

/* A null output returns the model's embedding dimension without computing. */
NEEDLE_API int needle_embed(
    const char* input,
    float* out,
    int out_capacity
);

NEEDLE_API void needle_reset(void);

NEEDLE_API int needle_load(
    const unsigned char* cact,
    unsigned long long n
);

#ifdef __cplusplus
}
#endif
#endif
```

## Alignment

android-arm64 needle (ELF) PT_LOAD segments:
- PT_LOAD[0]: p_align=0x4000 (16384)
- PT_LOAD[1]: p_align=0x4000 (16384)
- PT_LOAD[2]: p_align=0x4000 (16384)

All >= 0x4000: True
All == 0x4000: True

(Note: No .so files exist for android; only ELF exe + static .a)

## Symbols

### android-arm64
- **ELF needle executable**: 0 needle_* exports (stripped, dynsym has 118 entries, all libc imports)
- **libneedle.a static archive**: 6 needle_* C symbols defined in needle.cpp.o:
  - needle_complete (T)
  - needle_embed (T)
  - needle_init (T)
  - needle_last_error (T)
  - needle_load (T)
  - needle_reset (T)

### macos-arm64 / ios-arm64 / ios-sim-arm64
- **libneedle.a static archives**: All 6 needle_* C symbols (with _ prefix in Mach-O):
  - _needle_complete (T)
  - _needle_embed (T)
  - _needle_init (T)
  - _needle_last_error (T)
  - _needle_load (T)
  - _needle_reset (T)
- **macos-arm64 needle exe**: 4 exports (_needle_complete, _needle_init, _needle_load, _needle_reset)

## Weights size

needle3.cact present in all platform directories:

| Location | Size (bytes) |
|----------|--------------|
| engines/needle3.cact | 35,335,380 |
| engines/android-arm64/needle3.cact | 35,335,380 |
| engines/ios-arm64/needle3.cact | 35,335,380 |
| engines/ios-sim-arm64/needle3.cact | 35,335,380 |
| engines/macos-arm64/needle3.cact | 35,335,380 |
| engines-android/needle3.cact | 35,335,380 |

MD5: 71c31b0bb9dbbcbf64577a128a8d2e4a (all copies identical)

## Python reference output

Tool used: `add_note`
```json
{
  "name": "add_note",
  "description": "Save a note. Use when the user says note, write down, remember.",
  "input_schema": {
    "type": "object",
    "properties": {
      "text": {"type": "string"}
    },
    "required": ["text"]
  }
}
```

API call: `needle.Needle(tools=[add_note]).complete("remember to buy milk")`

Response envelope (sample):
```json
{
  "type": "call",
  "success": true,
  "function_calls": [
    {
      "name": "add_note",
      "arguments": {
        "text": "buy milk"
      }
    }
  ],
  "confidence": 0.1466,
  "prefill_tps": 3312.5,
  "decode_tps": 1706.9,
  "peak_ram_mb": 127.9
}
```

Embedding result: `needle.embed("buy milk")` returns vector of length **3072**

## Errors

1. **needle --version**: Command exits with `error: unrecognized arguments: --version` (no version flag implemented)
2. **android-arm64 ELF symbols**: `nm -g engines-android/needle` and `nm -gU` produce no needle_* output (binary is stripped)
3. **HuggingFace telemetry**: Unauthenticated-download warnings when loading weights (non-fatal, telemetry disabled via NEEDLE_TELEMETRY=0)
4. **rtk find with predicates**: `rtk find` does not support compound predicates (-not, -exec), -exec workaround required plain `find`

