import uuid

from django.contrib.auth.base_user import AbstractBaseUser
from django.contrib.auth.models import PermissionsMixin
from django.db import models

from apps.accounts.managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):
    """Email-based user. `role` and `status` are modeled as extensible
    enums, not booleans, specifically so the still-open questions in the
    spec (a Super Admin tier, a manual approval gate) can be absorbed later
    as a new enum value + permission branch rather than a schema rewrite.
    """

    class Role(models.TextChoices):
        ADMIN = "admin", "Admin"
        FELLOW = "fellow", "Fellow"

    class Status(models.TextChoices):
        PENDING_VERIFICATION = "pending_verification", "Pending verification"
        ACTIVE = "active", "Active"
        DISABLED = "disabled", "Disabled"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True, max_length=254, db_index=True)
    role = models.CharField(max_length=16, choices=Role.choices, default=Role.FELLOW)
    status = models.CharField(
        max_length=32, choices=Status.choices, default=Status.PENDING_VERIFICATION
    )
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    # AbstractBaseUser already provides `password` (hashed) and `last_login`.

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.email

    def save(self, *args, **kwargs):
        # Defense in depth for case-insensitive uniqueness without requiring
        # the Postgres citext extension: always persist lower-cased.
        self.email = self.email.lower()
        super().save(*args, **kwargs)

    @property
    def is_active(self) -> bool:
        return self.status != self.Status.DISABLED

    @property
    def is_admin_role(self) -> bool:
        return self.role == self.Role.ADMIN

    @property
    def is_fellow_role(self) -> bool:
        return self.role == self.Role.FELLOW


class AuthToken(models.Model):
    """Single-use, time-limited, hashed tokens for both email verification
    and password reset. One table rather than two — simpler than separate
    verify/reset tables for the same underlying shape.
    """

    class Purpose(models.TextChoices):
        EMAIL_VERIFY = "email_verify", "Email verification"
        PASSWORD_RESET = "password_reset", "Password reset"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="auth_tokens")
    purpose = models.CharField(max_length=16, choices=Purpose.choices)
    token_hash = models.CharField(max_length=128, db_index=True)
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "purpose", "used_at"], name="idx_token_user_purpose_used"),
        ]

    def __str__(self) -> str:
        return f"{self.purpose} token for {self.user_id}"

    @property
    def is_used(self) -> bool:
        return self.used_at is not None


class FellowProfile(models.Model):
    """Phase 1 shape only. Real profile fields (name, block, documents,
    consent) arrive in Phase 2 — deliberately not added here as speculative
    columns.
    """

    class OnboardingStep(models.TextChoices):
        ACCOUNT_CREATED = "account_created", "Account created"
        EMAIL_VERIFIED = "email_verified", "Email verified"
        PROFILE_PENDING = "profile_pending", "Profile pending"
        ACTIVE = "active", "Active"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="fellow_profile")
    onboarding_step = models.CharField(
        max_length=32,
        choices=OnboardingStep.choices,
        default=OnboardingStep.ACCOUNT_CREATED,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"FellowProfile({self.user_id}, {self.onboarding_step})"
