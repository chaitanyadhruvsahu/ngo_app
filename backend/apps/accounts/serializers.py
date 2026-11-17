from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenRefreshSerializer

from apps.accounts.models import Block, FellowProfile


class SignupSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_password(self, value: str) -> str:
        validate_password(value)
        return value


class VerifyEmailSerializer(serializers.Serializer):
    token = serializers.CharField()


class ResendVerificationSerializer(serializers.Serializer):
    email = serializers.EmailField()


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_new_password(self, value: str) -> str:
        validate_password(value)
        return value


class RefreshSerializer(TokenRefreshSerializer):
    """Renames simplejwt's default `access`/`refresh` output keys to the
    `access_token`/`refresh_token` shape used across this API's contract.
    """

    refresh_token = serializers.CharField(write_only=True)
    refresh = None  # replaced by refresh_token below

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields.pop("refresh", None)

    def validate(self, attrs):
        attrs["refresh"] = attrs.pop("refresh_token")
        data = super().validate(attrs)
        result = {"access_token": data["access"]}
        if "refresh" in data:
            result["refresh_token"] = data["refresh"]
        return result


class FellowProfileDetailSerializer(serializers.ModelSerializer):
    """The **single authorized detail view** for a fellow's full profile,
    including decrypted Aadhaar/bank values (Phase 2 mandate, Definition of
    Done). Used by `GET/PATCH /profile/me` (the fellow, their own record)
    and `GET /admin/fellows/{id}` (Admin, read-only). Never used for list
    responses — see `FellowProfileListSerializer` for those.
    """

    email = serializers.EmailField(source="user.email", read_only=True)
    block = serializers.PrimaryKeyRelatedField(
        queryset=Block.objects.filter(is_active=True), required=False, allow_null=True
    )

    class Meta:
        model = FellowProfile
        fields = [
            "id",
            "email",
            "block",
            "onboarding_step",
            "full_name",
            "date_of_birth",
            "phone_number",
            "address",
            "aadhaar_number",
            "bank_account_number",
            "bank_ifsc",
            "bank_account_holder_name",
            "consent_given_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "email", "onboarding_step", "consent_given_at", "created_at", "updated_at"]


class FellowProfileListSerializer(serializers.ModelSerializer):
    """Admin's fellow list — deliberately excludes Aadhaar/bank fields and
    every other detail-only field (Phase 2 mandate §L Testing / Definition
    of Done: sensitive values must never appear outside the single
    authorized detail view).
    """

    email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = FellowProfile
        fields = ["id", "email", "block", "full_name", "onboarding_step", "created_at"]
        read_only_fields = fields


class BlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = Block
        fields = ["id", "name", "number"]
        read_only_fields = ["id"]
