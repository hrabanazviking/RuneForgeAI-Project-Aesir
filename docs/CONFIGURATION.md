# Native Configuration Contract

`aesir.config.json` is parsed by a strict bounded Mojo JSON parser. Whitespace
and line layout are irrelevant. The root must be a JSON object containing only
the documented section objects; each field must occur in its owning section.
Duplicate or unknown sections/fields, wrong types, invalid UTF-8 or escapes,
non-JSON numbers, invalid ranges, trailing commas, and trailing content fail.

The schema accepts these optional sections and fields:

| Section | Fields and JSON types |
|---|---|
| `hardware` | `acceleration_backend` string, `target_npu` string, `num_gpu_layers` integer, `max_threads` integer |
| `safety` | `skaldbrodir_enabled` boolean, `thinking_enabled` boolean |
| `experimental_paradigms` | `cia_enabled`, `wic_enabled`, `nsfi_enabled`, `mqari_enabled` booleans |
| `interface` | `tui_enabled` boolean |
| `storage` | `model_store_path` string |
| `sampling` | `temperature` number, `top_p` number |

Omitted fields retain neutral defaults. `max_threads` must be nonnegative,
`num_gpu_layers` must be at least `-1`, `temperature` must be finite and
nonnegative, and `top_p` must be finite and between 0 and 1. The model-store
path must be a relative POSIX path using safe components; its default is
`.aesir/models`.

Configuration files are limited to 1 MiB, must be valid UTF-8, and are opened
without following a final symlink; raw NUL bytes and special files reject.
`aesir config --config <path> --format json`
validates the input and prints the normalized schema. Catalog commands also
accept `--config <path>` for the store root.

## CUDA chat and service layering

`chat` and `serve` accept `--config <file>` (`-c`), mutually exclusive with
`--model-store`. Duplicate selectors (including mixed aliases) reject before
opening files. Neither command automatically reads `aesir.config.json`.
Config store paths remain relative to the process working directory, not the
config file's directory, matching catalog commands.

Sampling precedence is native defaults < explicitly present config fields <
stored native recipe < explicit CLI flags < supported request/session overrides.
The existing `sampling.temperature` and `sampling.top_p` fields are connected;
other sampling controls, context/reply limits and system prompts still come from
recipes/CLI, not new JSON fields. `{}` preserves native top_p 0.95; explicitly
setting top_p to 1 overrides it. Explicit temperature 0 is retained.

Native top_p must be in (0, 1], unlike the legacy config schema's inclusive
lower bound. Native validation also rejects Float32 overflow and positive
temperature underflow to zero. Invalid config intent is never hidden by a
recipe or CLI override. `hardware.acceleration_backend` accepts only auto/cuda;
`--accel cuda` is still required. Non-neutral target_npu, num_gpu_layers,
max_threads, safety, experimental and tui_enabled values reject before model,
key, transcript or prompts access. Use `chat --tui` for its explicit TUI option.

```sh
aesir chat my-model --accel cuda --config personal.json --show-settings
aesir serve my-model --accel cuda -c personal.json --temperature 0 --show-settings
```

Preview is pre-planning intent, not architecture validation, hardware fit or
inference proof. Normal chat resolves the config once; `/model` carries current
sampling and the selected store through the existing process handoff without
rereading the config. Physical config-backed switches remain unverified.

The `config --format json` view materializes all neutral schema defaults; it is
not a presence-preserving export. Saving and reusing that output makes those
fields explicit (notably top_p 1). Existing catalog and single-shot behavior is
unchanged; single-shot `run` still rejects non-neutral sampling config.
Parsing other fields records intent, not implementation. The capability ledger
remains authoritative for each field's execution status.
