"""Provision initial pilot accounts once; never reset or elevate existing users."""
import os

from django.contrib.auth.password_validation import validate_password
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.accounts.models import FellowProfile, User


class Command(BaseCommand):
    help = "Create initial admin/fellow from PILOT_ADMIN_* and PILOT_FELLOW_*; preserve existing accounts."

    @transaction.atomic
    def handle(self, *args, **options):
        for role in ("admin", "fellow"):
            prefix = f"PILOT_{role.upper()}"
            email, password = os.environ.get(f"{prefix}_EMAIL"), os.environ.get(f"{prefix}_PASSWORD")
            if not email and not password:
                continue
            if not email or not password:
                raise CommandError(f"Both {prefix}_EMAIL and {prefix}_PASSWORD are required.")
            if User.objects.filter(email=email.lower()).exists():
                self.stdout.write(f"Existing {role} preserved.")
                continue
            validate_password(password)
            user = User.objects.create_user(
                email=email, password=password, role=role, status=User.Status.ACTIVE,
                is_staff=role == "admin", is_superuser=role == "admin",
            )
            if role == "fellow":
                FellowProfile.objects.create(
                    user=user, onboarding_step=FellowProfile.OnboardingStep.EMAIL_VERIFIED
                )
            self.stdout.write(f"Initial {role} created.")
