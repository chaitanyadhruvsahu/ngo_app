from django.contrib import admin

from apps.jobs.models import Job, JobAccessLog, JobStatusTransition, JobSubmission, JobSubmissionPhoto


class ReadOnlyHistoryAdmin(admin.ModelAdmin):
    """Lifecycle writes must go through the locked, audited API."""

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


class SubmissionHistoryAdmin(ReadOnlyHistoryAdmin):
    # Location is available only through the API that records each read.
    exclude = ("geotag_lat", "geotag_lng")


admin.site.register(JobSubmission, SubmissionHistoryAdmin)
for model in (Job, JobStatusTransition, JobSubmissionPhoto, JobAccessLog):
    admin.site.register(model, ReadOnlyHistoryAdmin)
