# Field encryption key custody and recovery procedure

Status: engineering procedure ready; named NGO/professor owner and backup custodian
are **pending appointment**. No production escrow has been established or verified.
Do not mark Phase 2 close-out complete until these responsibilities are accepted.

Direct escalation during the Phases 4–6 implementation: the user confirmed
“nobody right now” when asked to name the long-term custodian and recovery-drill
participants. Appointment remains unresolved; this is an ownership decision,
not an engineering task that a developer can silently close. No real custody or
recovery drill is claimed by the implementation tests.

## Ownership record to complete before real personal data

| Responsibility | Required record | Current status |
| --- | --- | --- |
| Accountable NGO/professor owner | Name, role, approved contact | Pending NGO decision |
| Backup custodian | A different named person and recovery contact | Pending NGO decision |
| Primary secret vault | Organisation-controlled vault and item identifier | Not provisioned |
| Separate recovery copy | Approved encrypted vault/offline escrow location | Not provisioned |
| Recovery approval | Named approvers and verification channel | Pending NGO decision |
| Retention and restore cadence | Backup retention and scheduled drill owner | Pending NGO decision |

Record identifiers and audit evidence here or in the NGO's operational register;
never paste actual keys into this repository, tickets, chat, screenshots or logs.

## Create and escrow

1. Appoint the custodians and organisation-owned accounts with MFA. Grant
   least-privilege vault access and enable audit logging; avoid a student's personal
   account as the only recovery route.
2. Generate a separate Fernet key per environment on an authorised machine using
   the command in `backend/.env.example`. Put it directly into the approved secret
   vault and inject it as `FIELD_ENCRYPTION_KEY` via the deployment secret manager.
3. Preserve an independent encrypted recovery copy controlled by the backup
   custodian. Keep database backups separate from the secret escrow and record the
   key version needed for every retained database backup.
4. Validate recovery in an isolated environment using a test encrypted record.
   Record only the date, participants, backup/key-version identifiers and pass/fail.
   Remove the restored test environment after the approved retention window.

## Rotate

Follow ADR-0010: escrow the new key first, deploy `new,old`, run
`python manage.py rotate_encryption_key`, verify representative encrypted fields,
then remove the old key from the live environment. **Retain the old key in escrow
for as long as any retained database backup still needs it.** Successful live-row
rotation does not re-encrypt historical backups. Do not expose decrypted fields in
logs or verification reports.

## Recover or respond to compromise

The owner and backup custodian verify the requester through their recorded channel,
approve recovery, and restore the matching database/key version into an isolated
environment. Verify decryption and record the audit event before restoring service.
For suspected compromise, revoke unauthorised vault access, rotate the key and
credentials, and let the NGO's incident owner assess affected personal data.
Loss of every applicable key copy makes those encrypted fields unrecoverable.

Re-run the restore drill after custodians change, after rotation, and at the cadence
approved by the NGO. Revoke departing custodians' access while preserving organisation
ownership and the independently verified recovery copy.
