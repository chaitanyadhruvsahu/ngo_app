from types import SimpleNamespace

from django.contrib.auth.models import AnonymousUser
from django.test import TestCase

from apps.accounts.models import User
from apps.accounts.permissions import IsAdmin, IsFellow


class RolePermissionTests(TestCase):
    """Phase 1 introduces no role-gated endpoints of its own, but the
    IsAdmin/IsFellow classes are the foundation every role-gated endpoint
    from Phase 2 onward will use, per the spec's testing mandate: "an Admin
    token must not reach a Fellow-only route and vice versa — test both
    directions."
    """

    @classmethod
    def setUpTestData(cls):
        cls.admin = User.objects.create_user(
            email="admin-perm@example.com", password="a-strong-password-1", role=User.Role.ADMIN
        )
        cls.fellow = User.objects.create_user(
            email="fellow-perm@example.com", password="a-strong-password-1", role=User.Role.FELLOW
        )
        cls.view = SimpleNamespace()

    def _request(self, user):
        return SimpleNamespace(user=user)

    def test_admin_permission_grants_admin(self):
        self.assertTrue(IsAdmin().has_permission(self._request(self.admin), self.view))

    def test_admin_permission_denies_fellow(self):
        self.assertFalse(IsAdmin().has_permission(self._request(self.fellow), self.view))

    def test_fellow_permission_grants_fellow(self):
        self.assertTrue(IsFellow().has_permission(self._request(self.fellow), self.view))

    def test_fellow_permission_denies_admin(self):
        self.assertFalse(IsFellow().has_permission(self._request(self.admin), self.view))

    def test_both_permissions_deny_anonymous(self):
        anon_request = self._request(AnonymousUser())
        self.assertFalse(IsAdmin().has_permission(anon_request, self.view))
        self.assertFalse(IsFellow().has_permission(anon_request, self.view))
