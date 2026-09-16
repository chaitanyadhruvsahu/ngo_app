from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

from apps.accounts.forms import UserChangeAdminForm, UserCreationAdminForm
from apps.accounts.models import FellowProfile, User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    """Admin accounts are provisioned here (or via `manage.py createsuperuser`),
    not through self-service signup — Admin = NGO staff, per the spec.
    """

    add_form = UserCreationAdminForm
    form = UserChangeAdminForm
    ordering = ["-created_at"]
    list_display = ["email", "role", "status", "is_staff", "created_at"]
    list_filter = ["role", "status", "is_staff"]
    search_fields = ["email"]
    readonly_fields = ["id", "created_at", "last_login"]

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Role & status", {"fields": ("role", "status")}),
        ("Permissions", {"fields": ("is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Important dates", {"fields": ("last_login", "created_at")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "password1", "password2", "role", "status", "is_staff", "is_superuser"),
            },
        ),
    )
    filter_horizontal = ("groups", "user_permissions")


@admin.register(FellowProfile)
class FellowProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "onboarding_step", "created_at"]
    list_filter = ["onboarding_step"]
    search_fields = ["user__email"]
    readonly_fields = ["id", "created_at"]
