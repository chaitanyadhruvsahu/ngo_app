from django.contrib.auth.forms import UserChangeForm, UserCreationForm

from apps.accounts.models import User


class UserCreationAdminForm(UserCreationForm):
    """Django's stock UserCreationForm assumes a `username` field; our
    custom User model has none (email is USERNAME_FIELD), so this rebinds
    it to email.
    """

    class Meta(UserCreationForm.Meta):
        model = User
        fields = ("email",)


class UserChangeAdminForm(UserChangeForm):
    class Meta(UserChangeForm.Meta):
        model = User
        fields = "__all__"
