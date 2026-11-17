from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import FellowProfile, User
from apps.volunteers.models import Volunteer


class VolunteerApiTests(APITestCase):
    """Covers Phase 2 Mandate #4 (403/404 test pair) for every volunteers
    endpoint, plus the duplicate-detection behavior from §G/§K.
    """

    def setUp(self):
        self.fellow_user = User.objects.create_user(
            email="fellow-vol@example.com", password="correct-horse-battery-1", status=User.Status.ACTIVE
        )
        self.fellow_profile = FellowProfile.objects.create(user=self.fellow_user)

        self.other_fellow_user = User.objects.create_user(
            email="other-fellow-vol@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        self.other_fellow_profile = FellowProfile.objects.create(user=self.other_fellow_user)

        self.admin_user = User.objects.create_user(
            email="admin-vol@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
            role=User.Role.ADMIN,
        )

    def _create(self, user, phone="9876543210", full_name="Test Volunteer"):
        self.client.force_authenticate(user=user)
        response = self.client.post(
            reverse("volunteer-list-create"), {"full_name": full_name, "phone_number": phone}
        )
        self.client.force_authenticate(user=None)
        return response

    # --- create / list / phone normalization ---

    def test_create_and_list_own_volunteers(self):
        response = self._create(self.fellow_user)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["phone_number"], "+919876543210")
        self.assertEqual(response.data["phone_number_raw"], "9876543210")

        self.client.force_authenticate(user=self.fellow_user)
        list_response = self.client.get(reverse("volunteer-list-create"))
        self.assertEqual(len(list_response.data), 1)

    def test_invalid_phone_number_is_rejected(self):
        response = self._create(self.fellow_user, phone="not-a-phone-number")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_duplicate_phone_for_same_fellow_is_rejected(self):
        first = self._create(self.fellow_user, phone="9876543210")
        self.assertEqual(first.status_code, status.HTTP_201_CREATED)

        second = self._create(self.fellow_user, phone="9876543210")
        self.assertEqual(second.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(second.data["error"]["code"], "duplicate_volunteer")

    def test_same_phone_across_different_fellows_is_allowed(self):
        first = self._create(self.fellow_user, phone="9876543210")
        second = self._create(self.other_fellow_user, phone="9876543210")
        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)

    # --- RBAC: Fellow vs Admin (Mandate #4) ---

    def test_admin_cannot_create_volunteers(self):
        response = self._create(self.admin_user)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_anonymous_cannot_list_volunteers(self):
        response = self.client.get(reverse("volunteer-list-create"))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_fellow_cannot_access_admin_fellow_volunteer_list(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(
            reverse("admin-fellow-volunteers", args=[self.other_fellow_profile.id])
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_list_any_fellows_volunteers(self):
        self._create(self.fellow_user)
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(reverse("admin-fellow-volunteers", args=[self.fellow_profile.id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    # --- ownership: 404 not 403 (Mandate #5) ---

    def test_fellow_cannot_read_another_fellows_volunteer(self):
        created = self._create(self.fellow_user)
        volunteer_id = created.data["id"]

        self.client.force_authenticate(user=self.other_fellow_user)
        response = self.client.get(reverse("volunteer-detail", args=[volunteer_id]))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_fellow_cannot_update_another_fellows_volunteer(self):
        created = self._create(self.fellow_user)
        volunteer_id = created.data["id"]

        self.client.force_authenticate(user=self.other_fellow_user)
        response = self.client.patch(reverse("volunteer-detail", args=[volunteer_id]), {"full_name": "x"})
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_fellow_cannot_delete_another_fellows_volunteer(self):
        created = self._create(self.fellow_user)
        volunteer_id = created.data["id"]

        self.client.force_authenticate(user=self.other_fellow_user)
        response = self.client.delete(reverse("volunteer-detail", args=[volunteer_id]))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Volunteer.objects.filter(id=volunteer_id).exists())

    def test_owner_can_update_and_delete_own_volunteer(self):
        created = self._create(self.fellow_user)
        volunteer_id = created.data["id"]

        self.client.force_authenticate(user=self.fellow_user)
        patch_response = self.client.patch(
            reverse("volunteer-detail", args=[volunteer_id]), {"full_name": "Updated Name"}
        )
        self.assertEqual(patch_response.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_response.data["full_name"], "Updated Name")

        delete_response = self.client.delete(reverse("volunteer-detail", args=[volunteer_id]))
        self.assertEqual(delete_response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Volunteer.objects.filter(id=volunteer_id).exists())
