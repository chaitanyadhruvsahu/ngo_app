from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from apps.accounts.models import AuthToken, FellowProfile, User
from apps.accounts.serializers import (
    LoginSerializer,
    LogoutSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RefreshSerializer,
    ResendVerificationSerializer,
    SignupSerializer,
    VerifyEmailSerializer,
)
from apps.accounts.services.audit import log_auth_event
from apps.accounts.services.email import EmailService
from apps.accounts.services.tokens import consume_token, issue_token
from apps.core.exceptions import error_response


def _blacklist_all_outstanding_tokens(user: User) -> None:
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


class SignupView(APIView):
    """Never reveals whether the email already had an account: the response
    is identical (201, same generic message) whether or not a new account
    was actually created.
    """

    permission_classes = [AllowAny]
    throttle_scope = "auth-sensitive"

    def post(self, request):
        serializer = SignupSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()
        password = serializer.validated_data["password"]

        user = User.objects.filter(email=email).first()
        if user is None:
            user = User.objects.create_user(email=email, password=password)
            FellowProfile.objects.create(user=user)
            issued = issue_token(user, AuthToken.Purpose.EMAIL_VERIFY)
            EmailService.send_verification_email(user, issued.raw_token)
            log_auth_event("signup", user_id=str(user.id))
        else:
            log_auth_event("signup_attempted_existing_email")

        return Response(
            {"message": "If this email can be registered, a verification email has been sent."},
            status=status.HTTP_201_CREATED,
        )


class VerifyEmailView(APIView):
    permission_classes = [AllowAny]
    throttle_scope = "auth-verify"

    def post(self, request):
        serializer = VerifyEmailSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token_record = consume_token(serializer.validated_data["token"], AuthToken.Purpose.EMAIL_VERIFY)
        if token_record is None:
            log_auth_event("verify_email_failed")
            return error_response(
                "invalid_token",
                "This verification link is invalid or has expired.",
                status.HTTP_400_BAD_REQUEST,
            )

        user = token_record.user
        # Per Assumption #4: no manual approval gate — email verification
        # alone activates the account.
        user.status = User.Status.ACTIVE
        user.save(update_fields=["status"])

        profile = getattr(user, "fellow_profile", None)
        if profile is not None:
            profile.onboarding_step = FellowProfile.OnboardingStep.EMAIL_VERIFIED
            profile.save(update_fields=["onboarding_step"])

        log_auth_event("email_verified", user_id=str(user.id))
        return Response({"message": "Email verified."}, status=status.HTTP_200_OK)


class ResendVerificationView(APIView):
    """Not in the Phase 1 API table but required by the Reliability
    section: account creation is decoupled from email delivery, so this is
    the retry path when the original verification email never arrived.
    """

    permission_classes = [AllowAny]
    throttle_scope = "auth-verify"

    def post(self, request):
        serializer = ResendVerificationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()

        user = User.objects.filter(email=email, status=User.Status.PENDING_VERIFICATION).first()
        if user is not None:
            issued = issue_token(user, AuthToken.Purpose.EMAIL_VERIFY)
            EmailService.send_verification_email(user, issued.raw_token)
            log_auth_event("verification_email_resent", user_id=str(user.id))

        return Response(
            {"message": "If this account needs verification, an email has been sent."},
            status=status.HTTP_202_ACCEPTED,
        )


class LoginView(APIView):
    """Generic 401 on any failure — unknown email, wrong password, unverified
    or disabled account are all indistinguishable to the caller.
    """

    permission_classes = [AllowAny]
    throttle_scope = "auth-sensitive"

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()
        password = serializer.validated_data["password"]

        user = User.objects.filter(email=email).first()
        credentials_valid = (
            user is not None
            and user.status == User.Status.ACTIVE
            and user.check_password(password)
        )

        if not credentials_valid:
            log_auth_event("login_failed", user_id=str(user.id) if user else None)
            return error_response(
                "invalid_credentials", "Invalid email or password.", status.HTTP_401_UNAUTHORIZED
            )

        user.last_login = timezone.now()
        user.save(update_fields=["last_login"])

        refresh = RefreshToken.for_user(user)
        log_auth_event("login_succeeded", user_id=str(user.id))

        return Response(
            {
                "access_token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "role": user.role,
            },
            status=status.HTTP_200_OK,
        )


class RefreshView(TokenRefreshView):
    permission_classes = [AllowAny]
    serializer_class = RefreshSerializer


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            RefreshToken(serializer.validated_data["refresh_token"]).blacklist()
        except TokenError:
            pass  # already invalid/expired/blacklisted — logout is idempotent
        log_auth_event("logout", user_id=str(request.user.id))
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]
    throttle_scope = "auth-sensitive"

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()

        user = User.objects.filter(email=email, status=User.Status.ACTIVE).first()
        if user is not None:
            issued = issue_token(user, AuthToken.Purpose.PASSWORD_RESET)
            EmailService.send_password_reset_email(user, issued.raw_token)
            log_auth_event("password_reset_requested", user_id=str(user.id))

        return Response(
            {"message": "If this email has an account, a password reset link has been sent."},
            status=status.HTTP_202_ACCEPTED,
        )


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]
    throttle_scope = "auth-sensitive"

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token_record = consume_token(
            serializer.validated_data["token"], AuthToken.Purpose.PASSWORD_RESET
        )
        if token_record is None:
            log_auth_event("password_reset_confirm_failed")
            return error_response(
                "invalid_token", "This reset link is invalid or has expired.", status.HTTP_400_BAD_REQUEST
            )

        user = token_record.user
        user.set_password(serializer.validated_data["new_password"])
        user.save(update_fields=["password"])

        _blacklist_all_outstanding_tokens(user)

        log_auth_event("password_reset_confirmed", user_id=str(user.id))
        return Response({"message": "Password has been reset."}, status=status.HTTP_200_OK)
