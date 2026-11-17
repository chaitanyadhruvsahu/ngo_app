from django.contrib import admin

from apps.volunteers.models import Volunteer


@admin.register(Volunteer)
class VolunteerAdmin(admin.ModelAdmin):
    list_display = ["full_name", "phone_number", "fellow_profile", "created_at"]
    search_fields = ["full_name", "phone_number", "fellow_profile__user__email"]
    readonly_fields = ["id", "created_at", "updated_at"]
