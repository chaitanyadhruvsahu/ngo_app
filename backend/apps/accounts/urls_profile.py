from django.urls import path

from apps.accounts.views_profile import ProfileMeView

urlpatterns = [
    path("me", ProfileMeView.as_view(), name="profile-me"),
]
