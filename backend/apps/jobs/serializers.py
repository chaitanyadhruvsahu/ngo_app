from decimal import Decimal

from django.conf import settings
from rest_framework import serializers

from apps.accounts.models import FellowProfile, User
from apps.jobs.models import Job, JobStatusTransition, JobSubmission, JobSubmissionPhoto


def assignees():
    return FellowProfile.objects.filter(user__role=User.Role.FELLOW, user__status=User.Status.ACTIVE)


class JobInputSerializer(serializers.Serializer):
    assigned_to = serializers.PrimaryKeyRelatedField(queryset=assignees())
    title = serializers.CharField(max_length=255)
    description = serializers.CharField(max_length=20000)
    expected_hours = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.01"))
    deadline = serializers.DateField(required=False, allow_null=True)
    internal_note = serializers.CharField(required=False, allow_blank=True, max_length=10000)


class JobEditSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255, required=False)
    description = serializers.CharField(max_length=20000, required=False)
    expected_hours = serializers.DecimalField(
        max_digits=6, decimal_places=2, min_value=Decimal("0.01"), required=False
    )
    deadline = serializers.DateField(required=False, allow_null=True)
    internal_note = serializers.CharField(required=False, allow_blank=True, max_length=10000)

    def to_internal_value(self, data):
        unknown = set(data) - set(self.fields)
        if unknown:
            raise serializers.ValidationError(
                {
                    "non_field_errors": (
                        "Only title, description, expected_hours, deadline and internal_note may be edited."
                    )
                }
            )
        return super().to_internal_value(data)


class ReassignSerializer(serializers.Serializer):
    assigned_to = serializers.PrimaryKeyRelatedField(queryset=assignees())
    reason = serializers.CharField(max_length=10000)


class ReviewSerializer(serializers.Serializer):
    submission_id = serializers.UUIDField()
    decision = serializers.ChoiceField(choices=["approved", "rejected"])
    reason = serializers.CharField(required=False, allow_blank=True, max_length=10000, default="")

    def validate(self, data):
        if data["decision"] == "rejected" and not data["reason"].strip():
            raise serializers.ValidationError({"reason": "A rejection reason is required."})
        return data


class SubmissionInputSerializer(serializers.Serializer):
    actual_hours = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.01"))
    device_timestamp = serializers.DateTimeField(required=False, allow_null=True)
    geotag_lat = serializers.DecimalField(
        max_digits=9, decimal_places=6, min_value=-90, max_value=90, required=False, allow_null=True
    )
    geotag_lng = serializers.DecimalField(
        max_digits=9, decimal_places=6, min_value=-180, max_value=180, required=False, allow_null=True
    )
    location_consent = serializers.BooleanField(required=False, default=False)

    def to_internal_value(self, data):
        data = data.copy()
        # Optional capture failures (including malformed device timestamps) do
        # not prevent the hours/photos workflow. Server time is authoritative.
        if "device_timestamp" in data:
            try:
                self.fields["device_timestamp"].run_validation(data["device_timestamp"])
            except serializers.ValidationError:
                data.pop("device_timestamp", None)
        consent = str(data.get("location_consent", "")).lower() in ("true", "1")
        data["location_consent"] = "true" if consent else "false"
        valid_location = settings.JOB_GEOTAG_ENABLED and consent
        if valid_location:
            for key in ("geotag_lat", "geotag_lng"):
                try:
                    if self.fields[key].run_validation(data.get(key)) is None:
                        valid_location = False
                except serializers.ValidationError:
                    valid_location = False
        if not valid_location:
            data.pop("geotag_lat", None)
            data.pop("geotag_lng", None)
        return super().to_internal_value(data)

    def validate(self, data):
        data.pop("location_consent", None)
        return data


class PhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = JobSubmissionPhoto
        fields = ["id", "content_type", "size_bytes", "checksum_sha256", "exif_captured_at", "uploaded_at"]


class SubmissionSerializer(serializers.ModelSerializer):
    photos = PhotoSerializer(many=True, read_only=True)

    class Meta:
        model = JobSubmission
        fields = [
            "id",
            "submitted_by",
            "actual_hours",
            "submitted_at",
            "device_timestamp",
            "geotag_lat",
            "geotag_lng",
            "reviewed_by",
            "review_status",
            "review_reason",
            "reviewed_at",
            "photos",
        ]


class TransitionSerializer(serializers.ModelSerializer):
    class Meta:
        model = JobStatusTransition
        fields = [
            "id",
            "from_status",
            "to_status",
            "actor",
            "reason",
            "from_assignee",
            "to_assignee",
            "created_at",
        ]


class FellowTransitionSerializer(TransitionSerializer):
    def to_representation(self, instance):
        data = super().to_representation(instance)
        if instance.from_status == "reassigned" or instance.to_status == "reassigned":
            data["reason"] = ""
            data["from_assignee"] = None
        return data


class FellowJobListSerializer(serializers.ModelSerializer):
    assigned_to_name = serializers.CharField(source="assigned_to.full_name", read_only=True)

    class Meta:
        model = Job
        fields = [
            "id",
            "created_by",
            "assigned_to",
            "assigned_to_name",
            "title",
            "description",
            "expected_hours",
            "deadline",
            "status",
            "created_at",
            "updated_at",
        ]


class AdminJobListSerializer(FellowJobListSerializer):
    class Meta(FellowJobListSerializer.Meta):
        fields = FellowJobListSerializer.Meta.fields + ["internal_note"]


class FellowJobDetailSerializer(FellowJobListSerializer):
    submissions = serializers.SerializerMethodField()
    transitions = serializers.SerializerMethodField()
    can_edit = serializers.ReadOnlyField()
    can_reassign = serializers.ReadOnlyField()

    class Meta(FellowJobListSerializer.Meta):
        fields = FellowJobListSerializer.Meta.fields + [
            "submissions",
            "transitions",
            "can_edit",
            "can_reassign",
        ]

    def get_submissions(self, obj):
        rows = obj.submissions.filter(assignment_revision=obj.assignment_revision).prefetch_related("photos")
        return SubmissionSerializer(rows, many=True).data

    def get_transitions(self, obj):
        return FellowTransitionSerializer(
            obj.transitions.filter(assignment_revision=obj.assignment_revision), many=True
        ).data


class AdminJobDetailSerializer(FellowJobDetailSerializer):
    class Meta(FellowJobDetailSerializer.Meta):
        fields = FellowJobDetailSerializer.Meta.fields + ["internal_note"]

    def get_submissions(self, obj):
        return SubmissionSerializer(obj.submissions.prefetch_related("photos"), many=True).data

    def get_transitions(self, obj):
        return TransitionSerializer(obj.transitions.all(), many=True).data
