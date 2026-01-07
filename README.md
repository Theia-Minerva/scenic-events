# scenic-events

**scenic-events** is a deterministic container format and decoding layer
for multiplexed event logs.

It answers one question:

> Which bytes belong to which logical stream, and how should they be interpreted?

The container owns **structure only**. Payload bytes remain opaque.

---

## What It Does

scenic-events is concerned only with:

- defining a binary container format
- declaring streams before use
- enforcing per-stream sequence monotonicity
- decoding records without allocations
- exposing raw payload bytes to consumers

---

## What It Is Not

scenic-events is **not**:

- an event producer
- a schema registry
- a catalog of event types
- a policy layer
- a persistence system
- a logging framework

It performs no I/O, no clocks, no implicit semantics, and no side effects.

---

## Relationship to scenic-kernel

- scenic-kernel is **pure and single-stream**
- scenic-events introduces **multiplexing at the container level**
- kernel bytes are opaque payloads here
- mapping from bytes to streams happens **outside** the kernel

---

## Repository Philosophy

Capabilities are added only when:

- the contract is explicit
- behavior is enforced by tests
- no semantics are implied beyond the container

If a requirement cannot be enforced by tests, it is not part of the contract.
