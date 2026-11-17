from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.db import connection
from django.test import TestCase, override_settings

from apps.accounts.models import FellowProfile, User
from apps.core.encrypted_fields import _fernet


class KeyRotationTests(TestCase):
    """ADR-0010: MultiFernet key rotation — old data stays readable while a
    new key takes over for new writes, and `rotate_encryption_key`
    re-encrypts existing rows under the new key without data loss.
    """

    OLD_KEY = "HH4WCilOr0khAJGIG7Y_syVorUx8Fcxn7pyzkhcq_74="
    NEW_KEY = "iOWXpjelpaYGY6NjU1VDGuqNBqkJjYMd7f64ZOxzgL0="

    def setUp(self):
        _fernet.cache_clear()
        self.addCleanup(_fernet.cache_clear)

    def _raw_column_value(self, user_id) -> str:
        database_user_id = User._meta.get_field("id").get_db_prep_value(user_id, connection)
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT aadhaar_number FROM accounts_fellowprofile WHERE user_id = %s",
                [database_user_id],
            )
            return cursor.fetchone()[0]

    @override_settings(FIELD_ENCRYPTION_KEY=OLD_KEY)
    def test_old_key_alone_can_read_data_it_wrote(self):
        user = User.objects.create_user(email="rotate-a@example.com", password="correct-horse-battery-1")
        FellowProfile.objects.create(user=user, aadhaar_number="111122223333")

        profile = FellowProfile.objects.get(user=user)
        self.assertEqual(profile.aadhaar_number, "111122223333")

    def test_new_primary_key_can_still_decrypt_rows_written_under_the_old_key(self):
        with override_settings(FIELD_ENCRYPTION_KEY=self.OLD_KEY):
            _fernet.cache_clear()
            user = User.objects.create_user(email="rotate-b@example.com", password="correct-horse-battery-1")
            FellowProfile.objects.create(user=user, aadhaar_number="444455556666")

        # New key prepended (new,old) — simulates step 1 of the rotation
        # procedure, before `rotate_encryption_key` has run.
        with override_settings(FIELD_ENCRYPTION_KEY=f"{self.NEW_KEY},{self.OLD_KEY}"):
            _fernet.cache_clear()
            profile = FellowProfile.objects.get(user=user)
            self.assertEqual(profile.aadhaar_number, "444455556666")

    def test_rotate_command_reencrypts_under_the_new_primary_key(self):
        with override_settings(FIELD_ENCRYPTION_KEY=self.OLD_KEY):
            _fernet.cache_clear()
            user = User.objects.create_user(email="rotate-c@example.com", password="correct-horse-battery-1")
            FellowProfile.objects.create(user=user, aadhaar_number="777788889999")
            raw_before = self._raw_column_value(user.id)

        with override_settings(FIELD_ENCRYPTION_KEY=f"{self.NEW_KEY},{self.OLD_KEY}"):
            _fernet.cache_clear()
            call_command("rotate_encryption_key")
            raw_after = self._raw_column_value(user.id)
            self.assertNotEqual(raw_before, raw_after)  # actually re-encrypted, not a no-op

            profile = FellowProfile.objects.get(user=user)
            self.assertEqual(profile.aadhaar_number, "777788889999")

        # Old key alone (fully dropped, step 3 of the rotation procedure)
        # can no longer read it — it's genuinely encrypted under the new
        # key now, not just re-wrapped.
        with override_settings(FIELD_ENCRYPTION_KEY=self.OLD_KEY):
            _fernet.cache_clear()
            with self.assertRaises(ImproperlyConfigured):
                _ = FellowProfile.objects.get(user=user).aadhaar_number
