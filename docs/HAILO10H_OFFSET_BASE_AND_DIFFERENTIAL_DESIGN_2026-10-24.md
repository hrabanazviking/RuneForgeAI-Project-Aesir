# Offset base RESOLVED + differential design (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.12 (AES-NUM-012),
continuing AES-NUM-011. Two parts: the pointer-offset base
question is answered from the pinned reader source; the
differential experiment that attacks word *meaning* is
designed.

## Part 1 — the offset base: RESOLVED (source level)

Pinned `hailort/libhailort/src/hef/hef.cpp` @ `d503417f`
(read this slice) defines, for header version 3 (the MiniLM
artifact's version):

```
m_offset_zero_point = HEF_HEADER_SIZE_V3
                    + hef_header.hef_proto_size
                    + hef_header.distinct.v3.hef_padding_size
```

and passes it as `ccws_offset` down the whole parse. The file
layout is therefore **header | protobuf | padding | CCWS
section**, and every `write_data_ccw_ptr` offset is relative
to the **start of the CCWS section** — neither file-absolute
nor protobuf-relative (the two candidates AES-NUM-011 could
not discriminate by sampling).

Numeric consistency against the artifact (11,759,616 B):
the protobuf measures ≈56.7 KB from byte 56, putting the
zero point at ≈56.8 KB; zero point + largest referenced end
(11,698,480) ≈ 11,755,300 ≤ file size, leaving ≈4.3 KB of
trailing additional-info — exactly the shape the v3 header
fields (`ccws_size_with_padding`, `additional_info_size`)
describe. The smallest referenced offset (1,862,144 into the
section) is consistent with the section holding all bulk
data — weights included — with the pointer bursts scattered
through it. The reader also **coalesces consecutive pointer
actions** into config-buffer writes (`hef.cpp`,
`build_write_ccw_actions`, ~line 2873): the action list is a
program of bursts, grouped at load.

**Grade: the base is ESTABLISHED at source level and
numerically consistent with the artifact.** (The exact
zero-point integer awaits a v3 header decode — a mechanical
step folded into the extraction work below, not a research
question.)

## Part 2 — differential design (word meaning)

Goal: force the first CCW word-field correlation. Design:

- **Pair requirement:** two Hailo-10H HEFs of the same
  network family differing by exactly ONE declared parameter.
  Ranked acquisition routes:
  1. **Model-zoo pair** — the twister checkout
     (`~/hailo10h-twister/hailo_model_zoo`) fetches per-model
     HEFs; two variants of one model (e.g. different input
     resolution or batch) are the cleanest pair.
  2. **Recipe rebuild** — the MiniLM corpus carries its
     `recipe/`; a rebuild with one knob changed (sequence
     length is the natural knob for a transformer) gives a
     same-source pair. (Uses the vendor compiler as a
     *measurement instrument* to manufacture evidence
     artifacts — the Aesir product path stays DFC-free per
     the owner scope; evidence generation is not the product.)
  3. **hailo-ollama store** — its pulled Qwen variants, once
     the store is located (inventory still owed).
- **Method:** parse both with the schema-guided walker;
  align the action lists; diff the (offset, size, channel)
  triples; for changed regions, extract the words under the
  resolved base and classify: words that move WITH the
  parameter vs words invariant. Any field that tracks the
  parameter exactly is a candidate encoding — graded
  EMPIRICAL-CANDIDATE until a third point confirms the track.
- **Stop conditions:** if no lawful pair can be acquired,
  the design falls back to intra-artifact differentials
  (the MiniLM HEF's own repeated layer blocks: six contexts
  of near-identical structure whose bursts differ only by
  their layer's data — a differential the corpus already
  contains).

## Evidence boundary

Base: established (source + numeric consistency). Word
meaning: untouched by this slice — the design above is the
instrument, the next slice runs it. Census: untouched
(4.13, driver trees).
