from django.conf import settings
from django.utils import timezone
from rest_framework import status
from rest_framework.exceptions import APIException
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


def _set_refresh_cookie(response: Response, refresh_token: str) -> None:
    """ADR-0007: web clients get the refresh token as an httpOnly cookie,
    scoped to the auth endpoints only, in addition to the JSON body (which
    mobile clients rely on — cookies are a web-only concern for us).
    """
    response.set_cookie(
        settings.REFRESH_TOKEN_COOKIE_NAME,
        refresh_token,
        httponly=True,
        secure=settings.REFRESH_TOKEN_COOKIE_SECURE,
        samesite=settings.REFRESH_TOKEN_COOKIE_SAMESITE,
        path=settings.REFRESH_TOKEN_COOKIE_PATH,
    )


def _clear_refresh_cookie(response: Response) -> None:
    response.delete_cookie(settings.REFRESH_TOKEN_COOKIE_NAME, path=settings.REFRESH_TOKEN_COOKIE_PATH)


def _refresh_token_from_request(request) -> str | None:
    """Prefer the httpOnly cookie (web); fall back to the JSON body (mobile,
    or any client that doesn't use cookies).
    """
    return request.COOKIES.get(settings.REFRESH_TOKEN_COOKIE_NAME) or request.data.get("refresh_token")


class EmailFlowUnavailable(APIException):
    status_code = 503
    default_code = "email_auth_disabled"
    default_detail = "Email registration and recovery are unavailable. Contact your NGO administrator."


class EmailFlowView(APIView):
    def initial(self, request, *args, **kwargs):
        if not settings.EMAIL_AUTH_ENABLED:
            raise EmailFlowUnavailable()
        return super().initial(request, *args, **kwargs)


class SignupView(EmailFlowView):
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


class VerifyEmailView(EmailFlowView):
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


class ResendVerificationView(EmailFlowView):
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
        # Carried into the access token automatically on every refresh (simplejwt
        # copies refresh-token claims onto the derived access token) so a web
        # client that never persists `role` locally can still recover it by
        # decoding its current access token after a silent cookie-based refresh.
        refresh["role"] = user.role
        log_auth_event("login_succeeded", user_id=str(user.id))

        response = Response(
            {
                "access_token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "role": user.role,
            },
            status=status.HTTP_200_OK,
        )
        _set_refresh_cookie(response, str(refresh))
        return response


class RefreshView(TokenRefreshView):
    """Accepts the refresh token from the httpOnly cookie (web) or the JSON
    body (mobile) — see ADR-0007. Since ROTATE_REFRESH_TOKENS is on, the
    rotated refresh token also gets re-cookied here.
    """

    permission_classes = [AllowAny]
    serializer_class = RefreshSerializer

    def post(self, request, *args, **kwargs):
        refresh_token = _refresh_token_from_request(request)
        if refresh_token is None:
            return error_response(
                "invalid_token", "No refresh token provided.", status.HTTP_401_UNAUTHORIZED
            )

        serializer = self.get_serializer(data={"refresh_token": refresh_token})
        try:
            serializer.is_valid(raise_exception=True)
        except TokenError:
            return error_response(
                "invalid_token",
                "This session has expired. Please log in again.",
                status.HTTP_401_UNAUTHORIZED,
            )

        data = serializer.validated_data
        response = Response(data, status=status.HTTP_200_OK)
        if "refresh_token" in data:
            _set_refresh_cookie(response, data["refresh_token"])
        return response


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = _refresh_token_from_request(request)
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except TokenError:
                pass  # already invalid/expired/blacklisted — logout is idempotent
        log_auth_event("logout", user_id=str(request.user.id))
        response = Response(status=status.HTTP_204_NO_CONTENT)
        _clear_refresh_cookie(response)
        return response


class PasswordResetRequestView(EmailFlowView):
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


class PasswordResetConfirmView(EmailFlowView):
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
