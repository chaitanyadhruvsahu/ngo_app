import uuid

from django.conf import settings
from django.db import models


class ExportLog(models.Model):
    class Type(models.TextChoices):
        FELLOW_CONTACT_LIST = "fellow_contact_list", "Fellow contacts"
        EVENT_PARTICIPANT_LIST = "event_participant_list", "Event candidate roster"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    run_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    export_type = models.CharField(max_length=32, choices=Type.choices)
    filters = models.JSONField(default=dict)
    run_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-run_at", "-id"]

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise ValueError("Export history cannot be changed.")
        return super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValueError("Export history cannot be deleted.")
