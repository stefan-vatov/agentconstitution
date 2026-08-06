---
status: normative
scope: [project-wide]
---
# Standards

Binding rules for all code in this repository.

## Evaluation model routing

Every evaluation model seat, including candidates, judges, simulated
personas, and downstream reference agents, must execute through the Pi
harness and use its own provider subscription directly. OpenRouter is
prohibited.

OpenCode Go may be used only as the provider for DeepSeek models. It must
never be used as the evaluation harness, and non-DeepSeek models must not
route through it.
