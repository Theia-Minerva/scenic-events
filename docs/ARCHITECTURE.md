# Architecture

This document describes the architectural role and boundaries of **scenic-events**.

It explains *what this library is*, *what it is not*, and *how it composes* with the rest of the scenic-* ecosystem.

This is a **structural** document, not a usage guide.

---

## Position in the scenic-* system

**scenic-events** sits *above* raw event producers and *below* semantic interpretation.

```
[event producers]
   ├─ scenic-kernel
   ├─ scenic-mac
   ├─ debugger / profiler
   └─ future tools
          ↓
   scenic-events
          ↓
[decoders / inspectors / replayers]
   ├─ scenic-mac tooling
   ├─ Dipole
   ├─ Dojo
   └─ offline analysis tools
```

It provides a **stable container and mapping layer** that allows independent consumers to understand:

* which bytes belong to which logical stream
* who produced each stream
* which schema should be used to interpret payloads

---

## Core responsibility

**scenic-events explains logs.**

It does not:

* create events
* assign meaning to payload bytes
* impose policy
* perform I/O
* allocate memory dynamically
* track time
* reorder records

Its sole responsibility is to make a byte stream *structurally intelligible* to an independent consumer.

---

## Architectural principles

### 1. Structural, not semantic

scenic-events understands **structure only**:

* container layout
* stream declarations
* record framing
* ordering
* identity

Payload bytes are treated as **opaque**.

All semantic interpretation happens *outside* this library.

---

### 2. Single container, multiple logical streams

A single physical log may contain many interleaved logical streams.

Each stream is declared explicitly with:

* `stream_id`
* producer namespace
* schema identifier
* producer version

This enables:

* correlation across subsystems
* deterministic replay
* inspection without prior context
* a single artifact per run

---

### 3. Declaration before use

Streams must be declared **before** any events reference them.

This invariant allows:

* streaming decode
* partial reads
* early rejection of malformed logs
* deterministic validation

The container never “discovers” streams implicitly.

---

### 4. Determinism and append-only semantics

scenic-events assumes and preserves:

* append-only writes
* deterministic ordering
* no mutation or re-interpretation of history

It does not checkpoint, compact, or rewrite logs.

---

### 5. Caller-owned resources

All storage is owned by the caller:

* output buffers
* input slices
* stream registry storage

This makes the library:

* predictable
* embeddable
* usable in constrained environments
* safe for systems tooling

---

## Relationship to scenic-kernel

* **scenic-kernel** produces a *single logical stream*
* It has no knowledge of multiplexing or containers
* It does not embed stream envelopes or metadata

scenic-events:

* does not change kernel bytes
* does not impose semantics on kernel events
* may reference kernel stream identity constants
* owns the mapping from bytes → stream

The kernel remains pure.

---

## Reader / Writer symmetry

The architecture enforces invariants in **both directions**:

* Writers enforce correctness at construction time
* Readers enforce correctness at consumption time

A malformed container:

* cannot be written accidentally
* cannot be read silently

This symmetry is intentional.

---

## Versioning model

The container has a single, explicit version in the file header.

Versioning applies to:

* container structure
* record framing
* declaration layout

Schema evolution:

* is external to scenic-events
* is keyed by schema identifiers
* does not require container changes

---

## What this library explicitly refuses to do

scenic-events will not:

* decode payloads
* define event catalogs
* register schemas globally
* manage files or paths
* allocate memory dynamically
* infer meaning from bytes
* introduce clocks or timestamps
* guess producer intent

If a feature proposal violates one of these, it belongs elsewhere.

---

## Extension model

scenic-events evolves only when **real usage** demands it.

New capabilities must:

* be justified by concrete consumers
* preserve determinism
* preserve append-only semantics
* be enforced by tests
* be documented in `EVENTS_CONTRACT.md`

If a capability cannot be enforced, it does not belong here.

---

## On-disk container layout (v0.1)

The scenic-events container is a **single, linear byte stream**.

It is written once, read sequentially, and never mutated.

All records appear **in order**, exactly as written.

---

### High-level structure

```
┌──────────────────────────────┐
│ File Header                  │
│  - Magic: "SCEV"              │
│  - Container Version (u8)     │
└──────────────────────────────┘
│                              │
│  Record Stream (0..N records) │
│                              │
└──────────────────────────────┘
```

There is no footer, index, or directory structure.

---

### Record stream

Each record begins with a **record kind byte**, followed by a kind-specific payload.

```
┌───────────┬─────────────────────────────┐
│ kind (u8) │ kind-specific fields…        │
└───────────┴─────────────────────────────┘
```

Record order is significant and preserved.

---

### Stream declaration record

Declares a logical stream and its identity.

```
┌───────────────┐
│ kind = 0x01   │  stream_decl
├───────────────┤
│ stream_id     │  u8
├───────────────┤
│ ns_len        │  u8
├───────────────┤
│ namespace     │  [ns_len] bytes
├───────────────┤
│ schema_id     │  u32 (little-endian)
├───────────────┤
│ prod_version  │  u32 (little-endian)
└───────────────┘
```

Rules:

* Must appear **before** any event records for that stream
* `stream_id` is immutable once declared
* Namespace bytes are opaque identifiers

---

### Event record

Carries opaque payload bytes for a declared stream.

```
┌───────────────┐
│ kind = 0x02   │  event
├───────────────┤
│ stream_id     │  u8
├───────────────┤
│ sequence      │  u32 (little-endian)
├───────────────┤
│ payload_len   │  u32 (little-endian)
├───────────────┤
│ payload       │  [payload_len] bytes
└───────────────┘
```

Rules:

* `stream_id` must already be declared
* `sequence` must be strictly monotonic *per stream*
* Payload bytes are uninterpreted by scenic-events

---

### Example interleaving

```
[Header]
[Decl stream 1: scenic.kernel]
[Decl stream 2: scenic.host]
[Event stream 1, seq 1]
[Event stream 2, seq 1]
[Event stream 1, seq 2]
[Event stream 2, seq 2]
```

Streams are logically independent but **physically interleaved**.

---

### Key properties of the layout

* Fully self-describing
* Streamable (can be decoded incrementally)
* Deterministic
* No forward references
* No hidden metadata
* No alignment padding

Any consumer with the container specification can decode structure
without knowing payload semantics.

---

This layout is normative only insofar as it is enforced by tests.
Future changes must preserve forward explainability.

---

## Summary

scenic-events is the **structural spine** of the scenic logging ecosystem.

It ensures that event logs remain:

* explainable
* inspectable
* reusable
* future-proof

without ever taking ownership of meaning.

Semantics are earned elsewhere.
