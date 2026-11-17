from django.core.management.base import BaseCommand

from apps.accounts.models import FellowProfile

_ENCRYPTED_FIELDS = ["aadhaar_number", "bank_account_number", "bank_ifsc"]


class Command(BaseCommand):
    """Re-encrypts every FellowProfile's encrypted fields under the current
    *primary* FIELD_ENCRYPTION_KEY (the first key in the comma-separated
    list — see ADR-0010).

    Rotation procedure:
      1. Prepend the new key to FIELD_ENCRYPTION_KEY (new,old) and deploy —
         MultiFernet still decrypts rows written under the old key.
      2. Run this command. Every row gets re-saved, which re-encrypts its
         encrypted fields under the new (now-primary) key.
      3. Once this has completed successfully, drop the old key from
         FIELD_ENCRYPTION_KEY and redeploy.
    """

    help = "Re-encrypts FellowProfile's encrypted fields under the current primary FIELD_ENCRYPTION_KEY."

    def handle(self, *args, **options):
        updated = 0
        # Re-saving forces get_prep_value() to re-encrypt with today's
        # primary key, regardless of which key (new or old) the stored
        # ciphertext was actually under — from_db_value() already tried
        # every configured key to read it back.
        for profile in FellowProfile.objects.all().iterator():
            profile.save(update_fields=_ENCRYPTED_FIELDS)
            updated += 1
        self.stdout.write(self.style.SUCCESS(f"Re-encrypted {updated} FellowProfile row(s)."))
