# Design: Gemma 3n properties and under-the-hood lesson

## Goal

Create one static, print-friendly HTML lesson that helps a learner who already
knows basic `flutter_gemma` model loading understand:

1. how generation properties affect quality, latency, memory, and output length;
2. how a Flutter/Dart request travels through `flutter_gemma` to native
   inference and back as streamed text;
3. which Gemma 3n capabilities are useful to explore next.

The lesson belongs at
`docs/lessons/0002-gemma-3n-properties-and-under-the-hood.html`.

## Audience and constraints

- Beginner-to-intermediate understanding of LLM application code.
- No JavaScript or local server required.
- Static HTML/CSS/SVG only; must print cleanly and remain readable on mobile.
- Teach one coherent mental model rather than becoming a full API manual.
- State that ranges are practical guidance, not universal guarantees; exact
  behavior depends on model artifact, runtime, quantization, and device.
- Cite trusted primary sources inline and link to existing teaching materials.

## Page structure

### 1. Opening mental model

Introduce the lesson as a tour of one response:

```text
prompt → formatted conversation → token IDs → transformer → next-token scores
       → sampling controls → decoded text chunk → Dart stream → UI
```

Explain that the application/runtime controls are distinct from the model's
learned weights and from native session lifecycle state.

### 2. Properties table

Use a responsive table with these columns:

- property;
- practical range or constraint;
- lower-end behavior;
- higher-end behavior;
- performance/resource trade-off;
- useful starting point in this app.

Cover:

- `temperature`;
- `topK`;
- `topP`;
- `randomSeed`;
- `maxTokens`;
- `maxOutputTokens`;
- `tokenBuffer`;
- stop tokens;
- `preferredBackend`;
- `supportImage` and `supportAudio`.

Make the crucial distinctions explicit:

- `temperature`, `topK`, and `topP` change token selection;
- `maxTokens` limits the whole context window;
- `maxOutputTokens` limits one generated reply;
- lifecycle controls determine when another request is safe.

### 3. Beginner under-the-hood diagram

Draw a static SVG/CSS flow diagram with two visually distinct lanes:

**Model computation lane**

```text
text → tokenizer → integer token IDs → transformer layers → logits
     → sampler → chosen token ID → detokenizer → text chunk
```

**Flutter/runtime lane**

```text
TextField → GemmaService → InferenceChat → native session
         ← TextResponse ← Dart stream/event bridge ← native text chunk
```

The diagram must state that Dart commonly receives decoded text chunks, not
raw integer token IDs. Note that a “token” in the Dart API can be a chunk that
contains one or more tokenizer tokens.

### 4. Communication walkthrough

Add a short numbered explanation of:

1. `Message.text` creation;
2. `transformToChatPrompt` applying model/file-type formatting;
3. `addQueryChunk` staging the prompt;
4. `generateResponseAsync` starting native inference;
5. MediaPipe EventChannel or LiteRT-LM FFI returning text chunks;
6. `TextResponse.token` reaching the service;
7. the UI appending chunks to its response buffer.

Tie this to the existing `PredictDone` lesson: a Dart stream is an observation
channel, while the native session owns prediction state.

### 5. Gemma 3n capability map

Include a table pairing each capability with a safe beginner experiment and
what to observe:

- text chat;
- conversation history/context;
- image understanding when the exact artifact/runtime supports vision;
- audio understanding when the exact artifact/runtime supports audio;
- streaming and cancellation;
- quantization/model-size comparisons;
- backend comparisons;
- structured JSON prompting and validation;
- offline behavior after installation.

Avoid claiming every Gemma 3n artifact exposes every modality through every
Flutter engine. Capability statements must be qualified by the model card and
runtime support.

### 6. Small experiment and completion check

Give a controlled experiment:

- hold model, prompt, backend, and seed constant;
- vary one property at a time;
- record first-token latency, total latency, output length, repetition, and
  usefulness;
- compare observations rather than assuming a setting is universally better.

End with six short questions covering tokenization, sampling, context/output
budgets, communication, and lifecycle safety. Include answers in a collapsible
or clearly separated review block so the lesson gives immediate feedback.

## Visual and accessibility design

- Use the visual style of lesson 0001: warm paper surface, teal headings, clear
  callouts, responsive layout, and print media rules.
- Use semantic headings, table headers, readable contrast, and descriptive SVG
  text/labels.
- Avoid relying on color alone to distinguish model and runtime lanes.
- Keep the diagram legible in grayscale printing.

## Sources

Use and link the existing `docs/RESOURCES.md` references, especially:

- `flutter_gemma` API/package documentation;
- Google AI Edge LLM Inference documentation;
- the Gemma 3n LiteRT-LM model card;
- the tokenizer reference;
- official generation-parameter documentation.

Update `docs/RESOURCES.md` only if a new source is needed; do not duplicate
source descriptions inside the lesson beyond concise inline citations.

## Acceptance criteria

- One file exists at the specified lesson path.
- It contains the complete property table, capability map, and both static flow
  diagrams.
- It links to the earlier lesson, reference sheet, mission, and resources.
- It explains the difference between Dart text chunks and native token IDs.
- It qualifies model/runtime-dependent capabilities.
- It is valid, readable static HTML with responsive and print styles.
- No JavaScript, external runtime, or new Flutter dependency is required.

## Out of scope

- Changing application code or generation defaults.
- Building an interactive slider/simulator.
- Benchmarking a device or claiming universal optimal parameter values.
- Teaching transformer mathematics beyond the next-token prediction mental
  model needed for diagnosis.
