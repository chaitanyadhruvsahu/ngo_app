from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import Block, FellowProfile, User


class BlockApiTests(APITestCase):
    """Phase 2 mandate pass 3, §3: fellow-picks-a-block-at-onboarding needs
    a way to list what's pickable.
    """

    def setUp(self):
        self.block_a = Block.objects.get(number=3)
        self.block_b = Block.objects.get(number=7)
        self.fellow_user = User.objects.create_user(
            email="fellow-blocks@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        FellowProfile.objects.create(user=self.fellow_user)

    def test_anonymous_cannot_list_blocks(self):
        response = self.client.get(reverse("block-list"))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_fellow_can_list_canonical_blocks_in_numeric_order(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(reverse("block-list"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        numbers = [block["number"] for block in response.data]
        self.assertEqual(numbers, [3, 7, 14, 19, 27, 29, 32])

    def test_fellow_can_set_their_own_block(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.patch(reverse("profile-me"), {"block": str(self.block_a.id)})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["block"], self.block_a.id)


class ProfileApiTests(APITestCase):
    """Covers Phase 2 Mandate #4 (403/404 test pair) for the profile/admin
    endpoints, plus the Definition of Done's "sensitive fields never leak
    outside the single authorized detail view" contract.
    """

    def setUp(self):
        self.block = Block.objects.create(name="Test Block")
        self.fellow_user = User.objects.create_user(
            email="fellow-profile@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        self.fellow_profile = FellowProfile.objects.create(
            user=self.fellow_user,
            block=self.block,
            full_name="Original Name",
            aadhaar_number="123412341234",
            bank_account_number="00011122233",
            bank_ifsc="HDFC0001234",
        )
        self.admin_user = User.objects.create_user(
            email="admin-profile@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
            role=User.Role.ADMIN,
        )

    # --- fellow: own profile ---

    def test_fellow_can_read_own_profile_including_sensitive_fields(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(reverse("profile-me"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["aadhaar_number"], "123412341234")
        self.assertEqual(response.data["bank_account_number"], "00011122233")

    def test_fellow_can_update_own_profile(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.patch(reverse("profile-me"), {"full_name": "Updated Name"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["full_name"], "Updated Name")
        self.fellow_profile.refresh_from_db()
        self.assertEqual(self.fellow_profile.full_name, "Updated Name")

    def test_admin_cannot_use_the_fellow_profile_endpoint(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(reverse("profile-me"))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_anonymous_cannot_read_profile(self):
        response = self.client.get(reverse("profile-me"))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    # --- admin: fellow list/detail ---

    def test_fellow_cannot_access_admin_fellow_list(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(reverse("admin-fellow-list"))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_list_fellows_without_sensitive_fields(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(reverse("admin-fellow-list"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data["results"]
        self.assertEqual(len(results), 1)
        # Contract: list responses never include Aadhaar/bank values.
        self.assertNotIn("aadhaar_number", results[0])
        self.assertNotIn("bank_account_number", results[0])
        self.assertNotIn("bank_ifsc", results[0])

    def test_admin_can_read_fellow_detail_including_sensitive_fields(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(reverse("admin-fellow-detail", args=[self.fellow_profile.id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["aadhaar_number"], "123412341234")

    def test_admin_fellow_detail_404s_for_unknown_id(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(
            reverse("admin-fellow-detail", args=["00000000-0000-0000-0000-000000000000"])
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_fellow_cannot_access_admin_fellow_detail(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(reverse("admin-fellow-detail", args=[self.fellow_profile.id]))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
