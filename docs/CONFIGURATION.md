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
without following a final symlink. `aesir config --config <path> --format json`
validates the input and prints the normalized schema. Catalog commands also
accept `--config <path>` for the store root.

Parsing a setting records intent; it does not create an implementation. Runtime
commands reject settings that do not belong to a supported execution path.
CUDA chat and service have their own explicit command options, and unavailable
hardware backends remain fail closed. The capability ledger is authoritative
for the current owner and execution status of each field.
