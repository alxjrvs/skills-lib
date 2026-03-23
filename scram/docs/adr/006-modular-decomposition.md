# ADR 006: Modular Decomposition

## Status
Accepted

## Context
SCRAM v7 used a single monolithic 566-line skill to serve four scales of work (Full, Lightweight, Quick, Nano) through degradation modes. Small work loaded the full process and skipped most of it. The tier system was a patch on a fundamentally heavyweight design — the skill was simultaneously too heavy for small work and too brittle for large work.

## Decision
Decompose SCRAM into three user-invocable skills:
- `/scram` — thin dispatcher (~100 lines) that assesses scope and routes to the right flow
- `/scram-solo` — purpose-built single-story flow (~150 lines) for work that doesn't need gates or integration branches
- `/scram-sprint` — full SCRAM flow (~300 lines) with gates, concurrent streams, and dual maintainers

The dispatcher owns scope assessment, session discovery, and scramstorm handoff. The flows own their own process logic.

## Consequences
- Breaking change to invocation patterns (v8.0.0)
- Solo runs load ~370 lines instead of ~920 (60% reduction)
- Tier system eliminated — two purpose-built flows replace four degradation modes
- Each flow can evolve independently
- Risk: dispatcher routing logic must be well-specified to prevent misrouting
