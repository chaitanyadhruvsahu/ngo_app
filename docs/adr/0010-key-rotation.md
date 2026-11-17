# ADR-0010: Field encryption key rotation via MultiFernet

**Status:** Accepted
**Date:** 2026-09-16
**Amends:** ADR-0008, which used a single `Fernet` instance with no rotation story.

**Operational amendment (2026-09-21):** See [key custody and recovery](../encryption-key-custody.md).
Remove retired keys from the live setting after rotation, but retain them in escrow
for retained database backups encrypted with those keys. Named ownership remains
an NGO/professor decision; engineering has not claimed custody on their behalf.

## Context

ADR-0008 encrypted Aadhaar/bank columns with a single `Fernet` key from `FIELD_ENCRYPTION_KEY`.
That has no rotation path: swapping the key would make every existing encrypted row
undecryptable the moment the new key deploys, since old rows are ciphertext under the old key and
the app would only ever try the new one. As real fellow data accumulates under Phase 2, that gap
gets more expensive to close later, not less — exactly the kind of thing ADR-0008 itself flagged
as "decide before real data exists."

## Decision

`FIELD_ENCRYPTION_KEY` now holds one or more comma-separated Fernet keys, parsed by
`apps.core.encrypted_fields.parse_field_encryption_keys` and wrapped in
`cryptography.fernet.MultiFernet`. `MultiFernet` encrypts with the *first* key only, and tries
every key in order when decrypting — so an old row stays readable for as long as its key is still
listed.

Rotation procedure (also documented inline in `.env.example` and the
`rotate_encryption_key` management command's docstring):

1. Prepend the new key: `FIELD_ENCRYPTION_KEY=<new>,<old>`. Deploy. New writes now use `<new>`;
   existing rows under `<old>` still read fine via `MultiFernet`'s fallback.
2. Run `python manage.py rotate_encryption_key` — it re-saves every `FellowProfile` row, which
   forces `EncryptedCharField.get_prep_value` to re-encrypt each field under the now-primary
   `<new>` key, regardless of which key the stored value was actually under.
3. Once that command completes successfully, drop `<old>` from `FIELD_ENCRYPTION_KEY` and
   redeploy. From this point, `<old>` is no longer needed to read anything.

A single key (no comma) still works exactly as before — `MultiFernet` with one key behaves
identically to using that `Fernet` directly, so this is backward compatible with every row
written under ADR-0008's original single-key scheme.

## Alternatives considered

- **Leave single-key, document "don't lose it, don't rotate it."** Rejected — a security control
  with no rotation story is a control you can never safely respond to a suspected key compromise
  with, which defeats much of the point of having a rotatable secret in the first place.
- **A separate one-off script instead of a `manage.py` command.** Rejected — this needs to be a
  repeatable, discoverable, ordinary part of the deploy toolchain (same reason `seed_admin` is a
  management command and not a one-off script), not something that has to be rediscovered or
  rewritten the next time rotation is needed.
- **Store key version alongside each encrypted value, decrypt with only the exact matching key.**
  More explicit, but `MultiFernet`'s try-each-in-order approach needs no extra column and no
  migration to add one — simpler, and the failure mode (decrypt fails, `ImproperlyConfigured`
  raised loudly) is the same either way once a key truly falls out of the list.

## Consequences / trade-offs

- `rotate_encryption_key` loads and re-saves every `FellowProfile` row — fine at this app's scale
  (a single NGO's fellows), would need batching/chunking if this table ever grew to a size where
  that's a real concern. Not a problem worth solving speculatively now.
- The rotation procedure is manual (three explicit steps, no automation deciding "when" to
  rotate) — appropriate for how rarely this should happen (suspected compromise, or a routine
  security hygiene cadence the NGO sets, not something automatic).
- `FIELD_ENCRYPTION_KEY`'s backup/escrow story (flagged as unresolved in ADR-0008) still isn't
  answered by this ADR — rotation capability doesn't substitute for a real answer on who holds
  this secret long-term.

## Reversibility

High — this only changed how the key setting is parsed and added one new management command;
nothing about `EncryptedCharField`'s public behavior (its `get_prep_value`/`from_db_value`
contract) changed for callers.
