from rest_framework import serializers

from apps.accounts.models import Block, User
from apps.notifications.models import Notification, NotificationRecipientState


class NotificationSerializer(serializers.ModelSerializer):
    # English is the authoring language for this prototype. Older bilingual
    # announcements remain readable; no machine translation is implied.
    title_hi = serializers.CharField(required=False, allow_blank=True, default="", max_length=200)
    body_hi = serializers.CharField(required=False, allow_blank=True, default="", max_length=4000)
    target_user = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(status=User.Status.ACTIVE), required=False, allow_null=True
    )
    target_block = serializers.PrimaryKeyRelatedField(
        queryset=Block.objects.filter(is_active=True, number__isnull=False), required=False, allow_null=True
    )

    class Meta:
        model = Notification
        fields = [
            "id",
            "type",
            "title_en",
            "title_hi",
            "body_en",
            "body_hi",
            "target_user",
            "target_block",
            "scheduled_time",
            "remind_before",
            "channel",
            "created_at",
            "delivered_at",
            "source_job",
            "cancelled_at",
        ]
        read_only_fields = ["id", "created_at", "delivered_at", "source_job", "cancelled_at"]

    def validate(self, attrs):
        if bool(attrs.get("target_user")) == bool(attrs.get("target_block")):
            raise serializers.ValidationError({"target_user": "Choose exactly one person or block."})
        return attrs


class RecipientSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField(source="notification_id")
    type = serializers.CharField(source="notification.type")
    channel = serializers.CharField(source="notification.channel")
    title_en = serializers.CharField(source="notification.title_en")
    title_hi = serializers.CharField(source="notification.title_hi")
    body_en = serializers.CharField(source="notification.body_en")
    body_hi = serializers.CharField(source="notification.body_hi")
    scheduled_time = serializers.DateTimeField(source="notification.scheduled_time")
    source_job = serializers.UUIDField(source="notification.source_job_id", allow_null=True)

    class Meta:
        model = NotificationRecipientState
        fields = [
            "id",
            "type",
            "channel",
            "title_en",
            "title_hi",
            "body_en",
            "body_hi",
            "scheduled_time",
            "read_at",
            "dismissed_at",
            "source_job",
        ]
