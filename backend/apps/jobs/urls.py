from django.urls import path

from apps.jobs import views

urlpatterns = [
    path("jobs", views.JobListCreateView.as_view(), name="job-list"),
    path("jobs/config", views.JobConfigView.as_view(), name="job-config"),
    path("jobs/mine", views.MyJobsView.as_view(), name="job-mine"),
    path("jobs/<uuid:pk>", views.JobDetailView.as_view(), name="job-detail"),
    path("jobs/<uuid:pk>/start", views.JobStartView.as_view(), name="job-start"),
    path("jobs/<uuid:pk>/submissions", views.JobSubmissionView.as_view(), name="job-submit"),
    path("jobs/<uuid:pk>/review", views.JobReviewView.as_view(), name="job-review"),
    path("jobs/<uuid:pk>/reassign", views.JobReassignView.as_view(), name="job-reassign"),
    path("jobs/<uuid:pk>/photos/<uuid:photo_id>", views.JobPhotoView.as_view(), name="job-photo"),
]
