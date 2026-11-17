import uuid

from django.db import models

from apps.accounts.models import FellowProfile


class Volunteer(models.Model):
    """A person a fellow has mapped as a volunteer under them.

    Duplicate detection: unique within one fellow's own list on the
    normalized phone number (below) — a fellow can't add the same person
    twice. Cross-fellow duplicates (the same phone number under two
    different fellows) are *not* blocked — the same person could
    legitimately appear under more than one fellow — and are left for
    Admin review rather than enforced here (Phase 2 mandate, Data
    Architecture).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    fellow_profile = models.ForeignKey(FellowProfile, on_delete=models.CASCADE, related_name="volunteers")
    full_name = models.CharField(max_length=255)
    # E.164-normalized (see services.phone.normalize_phone_number).
    phone_number = models.CharField(max_length=32)
    phone_number_raw = models.CharField(max_length=32)
    relationship_to_fellow = models.CharField(max_length=255, blank=True)
    household_details = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["fellow_profile", "phone_number"], name="uniq_volunteer_per_fellow_phone"
            ),
        ]

    def __str__(self) -> str:
        return f"Volunteer({self.full_name}, fellow={self.fellow_profile_id})"
