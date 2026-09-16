from apps.accounts.models import User
from apps.core.permissions import HasRole


class IsAdmin(HasRole):
    allowed_roles = (User.Role.ADMIN,)


class IsFellow(HasRole):
    allowed_roles = (User.Role.FELLOW,)
