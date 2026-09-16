# ADR-0004: Flutter state management — Riverpod

**Status:** Accepted
**Date:** 2026-09-16

## Context

The team is small and rotates each semester; whatever state-management approach is chosen has
to be learnable quickly by a new contributor.

## Decision

Use Riverpod for state management and dependency injection across the Flutter app.

## Alternatives considered

- **Provider:** Riverpod's predecessor, more error-prone at scale (runtime context lookups,
  easier to misuse).
- **Bloc:** more structure and stricter conventions, but a noticeably steeper ramp for a new
  contributor each semester.

## Consequences / trade-offs

- Less boilerplate than Bloc, compile-safe DI, strong current documentation.
- Core business logic is kept in plain Dart service classes, not tangled into providers, so it
  isn't tightly coupled to the state-management library.

## Reversibility

Medium — mitigated by keeping business logic in plain Dart services behind the providers.
