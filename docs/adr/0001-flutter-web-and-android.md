# ADR-0001: Single Flutter codebase for Web and Android

**Status:** Accepted
**Date:** 2026-09-16

## Context

The master requirements doc's §10 suggested a PWA. A later roadmap doc confirms a different,
explicit requirement: one Flutter codebase producing both a web build and an Android APK. The
roadmap doc is the more recent, explicitly confirmed decision, so it overrides the PWA
suggestion.

## Decision

Build the client as a single Flutter codebase (`/app`) targeting Web and Android from day one.

## Alternatives considered

- **PWA (per the original master doc):** would have given free service-worker offline caching,
  but contradicts the roadmap's confirmed requirement.
- **Separate native Android app + separate web app:** doubles the maintenance burden for a
  small, rotating student team — rejected outright.

## Consequences / trade-offs

- No free service-worker caching for offline use (a Phase 5 concern, not Phase 0/1).
- One Dart codebase, one set of business-logic tests, consistent UX across platforms.
- CI must build both a web bundle and an Android APK on every merge.

## Reversibility

Low-medium once Phase 2+ features are built on Flutter widgets/Riverpod. Revisit only if the
roadmap's platform requirement itself changes.
