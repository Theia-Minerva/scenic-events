# Events Contract

This document captures the *minimal, enforceable contracts* of scenic-events.

Each clause exists only if it is enforced by at least one test.
Contracts are added incrementally and removed if no longer justified by use.

---

## Core Invariants

Clauses marked **Enforced by tests** are normative.

### EC-01: Valid Header Required

A container starts with a fixed magic and version.

- The header must appear before any records.
- Unknown magic values are rejected.
- Unsupported versions are rejected.

**Enforced by tests:**
- [`tests/container_roundtrip_test.zig`](tests/container_roundtrip_test.zig)

### EC-02: Streams Must Be Declared Before Use

Events may only reference streams that have already been declared.

- Events that reference unknown stream IDs are rejected.
- Events that appear before a stream declaration are rejected.

**Enforced by tests:**
- [`tests/invariants_test.zig`](tests/invariants_test.zig)

### EC-03: Stream IDs Are Immutable

Stream IDs are declared once and never redefined.

- Redeclaration of an existing stream ID is rejected.

**Enforced by tests:**
- [`tests/invariants_test.zig`](tests/invariants_test.zig)

### EC-04: Per-Stream Sequence Is Monotonic

Event sequence numbers are monotonic per stream.

- A sequence value must be strictly greater than the last accepted value.

**Enforced by tests:**
- [`tests/invariants_test.zig`](tests/invariants_test.zig)

### EC-05: Record Ordering Is Preserved

Records are decoded in the order they appear in the byte stream.

**Enforced by tests:**
- [`tests/invariants_test.zig`](tests/invariants_test.zig)

---

This contract is enforced by tests.
Changes to this document must be justified by failing tests and real usage.
