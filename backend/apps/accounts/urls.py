from django.urls import path

from apps.accounts.views import (
    LoginView,
    LogoutView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    RefreshView,
    ResendVerificationView,
    SignupView,
    VerifyEmailView,
)

urlpatterns = [
    path("signup", SignupView.as_view(), name="auth-signup"),
    path("verify-email", VerifyEmailView.as_view(), name="auth-verify-email"),
    path("resend-verification", ResendVerificationView.as_view(), name="auth-resend-verification"),
    path("login", LoginView.as_view(), name="auth-login"),
    path("refresh", RefreshView.as_view(), name="auth-refresh"),
    path("logout", LogoutView.as_view(), name="auth-logout"),
    path("password-reset/request", PasswordResetRequestView.as_view(), name="auth-password-reset-request"),
    path("password-reset/confirm", PasswordResetConfirmView.as_view(), name="auth-password-reset-confirm"),
]
