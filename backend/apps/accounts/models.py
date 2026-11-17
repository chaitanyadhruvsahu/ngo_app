import uuid

from django.contrib.auth.base_user import AbstractBaseUser
from django.contrib.auth.models import PermissionsMixin
from django.db import models

from apps.accounts.managers import UserManager
from apps.core.encrypted_fields import EncryptedCharField


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
    status = models.CharField(max_length=32, choices=Status.choices, default=Status.PENDING_VERIFICATION)
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


class Block(models.Model):
    """Geographic/administrative unit a fellow is assigned to. Referenced by
    the Phase 2 mandate as though it already existed from Phase 1 — it
    didn't; Phase 1 only shipped auth, not org structure. Added here,
    minimal by design: block-based filtering/management is explicitly
    Phase 4 scope, so this is only what `FellowProfile.block` needs to
    exist as a real FK target now, per that mandate's own Assumption 3.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Number(models.IntegerChoices):
        THREE = 3, "3"
        SEVEN = 7, "7"
        FOURTEEN = 14, "14"
        NINETEEN = 19, "19"
        TWENTY_SEVEN = 27, "27"
        TWENTY_NINE = 29, "29"
        THIRTY_TWO = 32, "32"

    number = models.PositiveSmallIntegerField(choices=Number.choices, unique=True, null=True, blank=True)
    name = models.CharField(max_length=255, null=True, blank=True)
    # Unmapped legacy rows remain attached to their historical fellows, but
    # cannot be selected for a new assignment or mistaken for real blocks.
    is_active = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["number", "name"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(number__in=[3, 7, 14, 19, 27, 29, 32]) | models.Q(number__isnull=True),
                name="block_canonical_number",
            ),
            models.CheckConstraint(
                condition=models.Q(is_active=False) | models.Q(number__isnull=False),
                name="active_block_must_be_mapped",
            ),
        ]

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)

    def __str__(self) -> str:
        return self.name or (f"Block {self.number}" if self.number else "Legacy unmapped block")


class FellowProfile(models.Model):
    """Phase 1 shape plus Phase 2's structured profile fields. Aadhaar/bank
    columns are encrypted at the application layer (ADR-0008) — see
    `apps.core.encrypted_fields.EncryptedCharField`.
    """

    class OnboardingStep(models.TextChoices):
        ACCOUNT_CREATED = "account_created", "Account created"
        EMAIL_VERIFIED = "email_verified", "Email verified"
        PROFILE_PENDING = "profile_pending", "Profile pending"
        ACTIVE = "active", "Active"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="fellow_profile")
    block = models.ForeignKey(
        Block, on_delete=models.PROTECT, related_name="fellow_profiles", null=True, blank=True
    )
    onboarding_step = models.CharField(
        max_length=32,
        choices=OnboardingStep.choices,
        default=OnboardingStep.ACCOUNT_CREATED,
    )

    full_name = models.CharField(max_length=255, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    address = models.TextField(blank=True)

    # Encrypted at the application layer (ADR-0008) — not queryable/filterable
    # by value, which nothing in the spec requires.
    aadhaar_number = EncryptedCharField(max_length=32, blank=True, default="")
    bank_account_number = EncryptedCharField(max_length=64, blank=True, default="")
    bank_ifsc = EncryptedCharField(max_length=16, blank=True, default="")
    # Not encrypted — a name alone isn't the sensitive part; the account
    # number/IFSC pairing is (see Phase 2 mandate, Data Architecture).
    bank_account_holder_name = models.CharField(max_length=255, blank=True)

    # Schema-ready for the still-open data consent policy question (Phase 2
    # mandate, Assumption 4) — no consent *flow* built until that's answered.
    consent_given_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"FellowProfile({self.user_id}, {self.onboarding_step})"
