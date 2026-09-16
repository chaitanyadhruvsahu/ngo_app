"""Base, app-agnostic permission classes.

DRF's default here is DEFAULT_PERMISSION_CLASSES = IsAuthenticated (see
config/settings.py), so any view that forgets to declare permission_classes
fails closed rather than open. Role-specific permission classes (IsAdmin,
IsFellow) live in apps.accounts.permissions since "role" is a concept owned
by the User model, but they build on HasRole defined here so the fail-closed
pattern is shared.
"""
from rest_framework.permissions import BasePermission


class HasRole(BasePermission):
    """Grants access only to authenticated users whose `role` attribute is
    in `allowed_roles`. Subclass and set `allowed_roles` rather than
    instantiating directly.
    """

    allowed_roles: tuple[str, ...] = ()
    message = "You do not have permission to access this resource."

    def has_permission(self, request, view) -> bool:
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and getattr(user, "role", None) in self.allowed_roles
        )
