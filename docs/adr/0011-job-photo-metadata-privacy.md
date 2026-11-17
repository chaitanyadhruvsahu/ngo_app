# ADR-0011: Sanitize stored job photos and retain only a separate capture timestamp

**Status:** Accepted
**Date:** 2026-09-21

## Context

The master requirements recommend preserving original, unedited image metadata
where possible for fraud investigation. Phase 3 instead decodes evidence images,
extracts an optional EXIF capture timestamp with timezone, applies orientation,
and re-encodes pixels as JPEG without EXIF, GPS, XMP, or comments. This is an
intentional deviation from that guidance, now recorded explicitly.

## Decision

Continue storing sanitized images only. Preserve `exif_captured_at` separately
when a parseable capture timestamp and timezone offset exist, alongside the
server-recorded submission time. Missing or malformed metadata never prevents
otherwise valid evidence from being submitted. Optional location is separately
consented, feature-gated, and access-logged; an image must not bypass those controls
by silently retaining embedded GPS.

Native capture restricts the normal Android flow to taking a new camera photo,
and the timestamp comparison supplies an additional review signal. Browser
uploads remain explicitly identified as browser evidence. Neither client capture
source nor EXIF timestamps are tamper-proof attestations, and the server cannot
prove that a modified client used the camera. These signals support human review,
not automatic fraud findings.

## Trade-off

The system gives up forensic re-verification against untouched original bytes
and metadata, as well as metadata not explicitly extracted. It gains avoidance
of permanently stored GPS-tagged originals and incidental device metadata.
Native capture plus separate capture/submission timestamps is judged sufficient
for the current program's evidence review needs without retaining that privacy
liability. The extracted timestamp is best-effort, not ground truth.

## Reversibility

A future need for original forensic evidence requires a new retention/access
decision and explicit privacy review. Originals already discarded cannot be
reconstructed from sanitized images; changing the policy would affect future
uploads only.
