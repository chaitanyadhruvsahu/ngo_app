from django.db import connection
from django.test import TestCase

from apps.accounts.models import FellowProfile, User


class EncryptedFieldRoundTripTests(TestCase):
    """Phase 2 mandate §L: field encryption round-trips correctly, and the
    raw DB column never contains the plaintext (ADR-0008).
    """

    def test_aadhaar_and_bank_fields_round_trip_through_the_orm(self):
        user = User.objects.create_user(
            email="encrypted-fields@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        profile = FellowProfile.objects.create(
            user=user,
            aadhaar_number="123412341234",
            bank_account_number="000111222333",
            bank_ifsc="SBIN0001234",
        )

        profile.refresh_from_db()
        self.assertEqual(profile.aadhaar_number, "123412341234")
        self.assertEqual(profile.bank_account_number, "000111222333")
        self.assertEqual(profile.bank_ifsc, "SBIN0001234")

    def test_raw_database_column_does_not_contain_plaintext(self):
        user = User.objects.create_user(
            email="encrypted-fields-raw@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        FellowProfile.objects.create(user=user, aadhaar_number="999988887777")

        database_user_id = User._meta.get_field("id").get_db_prep_value(user.id, connection)
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT aadhaar_number FROM accounts_fellowprofile WHERE user_id = %s",
                [database_user_id],
            )
            raw_value = cursor.fetchone()[0]

        self.assertNotIn("999988887777", raw_value)

    def test_blank_value_is_not_encrypted_or_decrypted(self):
        user = User.objects.create_user(
            email="encrypted-fields-blank@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        profile = FellowProfile.objects.create(user=user)
        profile.refresh_from_db()
        self.assertEqual(profile.aadhaar_number, "")
