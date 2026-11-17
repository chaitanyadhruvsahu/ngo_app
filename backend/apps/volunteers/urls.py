from django.urls import path

from apps.volunteers.views import VolunteerDetailView, VolunteerListCreateView

urlpatterns = [
    path("", VolunteerListCreateView.as_view(), name="volunteer-list-create"),
    path("<uuid:pk>", VolunteerDetailView.as_view(), name="volunteer-detail"),
]
