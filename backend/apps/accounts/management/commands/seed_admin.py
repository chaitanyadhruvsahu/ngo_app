import os

from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import User


class Command(BaseCommand):
    """Idempotently provisions (or updates) a single Admin account from
    environment variables. Admin accounts are NGO staff and are never
    self-registered (see Assumption #5 / ADR context) — this is the
    non-interactive alternative to `manage.py createsuperuser` for use in
    a deploy pipeline or a fresh environment.

    Usage: ADMIN_EMAIL=... ADMIN_PASSWORD=... python manage.py seed_admin
    """

    help = "Create or update the seed Admin account from ADMIN_EMAIL / ADMIN_PASSWORD env vars."

    def handle(self, *args, **options):
        email = os.environ.get("ADMIN_EMAIL")
        password = os.environ.get("ADMIN_PASSWORD")

        if not email or not password:
            raise CommandError("ADMIN_EMAIL and ADMIN_PASSWORD environment variables are required.")

        user, created = User.objects.get_or_create(
            email=email.lower(),
            defaults={
                "role": User.Role.ADMIN,
                "status": User.Status.ACTIVE,
                "is_staff": True,
                "is_superuser": True,
            },
        )
        user.set_password(password)
        user.role = User.Role.ADMIN
        user.status = User.Status.ACTIVE
        user.is_staff = True
        user.is_superuser = True
        user.save()

        verb = "Created" if created else "Updated"
        self.stdout.write(self.style.SUCCESS(f"{verb} admin account for {user.email}."))
