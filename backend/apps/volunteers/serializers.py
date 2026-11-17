from rest_framework import serializers

from apps.volunteers.models import Volunteer
from apps.volunteers.services import InvalidPhoneNumber, normalize_phone_number


class VolunteerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Volunteer
        fields = [
            "id",
            "full_name",
            "phone_number",
            "phone_number_raw",
            "relationship_to_fellow",
            "household_details",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "phone_number_raw", "created_at", "updated_at"]

    def validate_phone_number(self, value: str) -> str:
        try:
            return normalize_phone_number(value)
        except InvalidPhoneNumber as exc:
            raise serializers.ValidationError(str(exc)) from exc

    def create(self, validated_data):
        raw = self.initial_data.get("phone_number", "")
        validated_data["phone_number_raw"] = raw
        return super().create(validated_data)

    def update(self, instance, validated_data):
        if "phone_number" in validated_data:
            validated_data["phone_number_raw"] = self.initial_data.get("phone_number", "")
        return super().update(instance, validated_data)
