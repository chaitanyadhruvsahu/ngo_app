from django.core.management.base import BaseCommand

from apps.notifications.services import deliver_due


class Command(BaseCommand):
    help = "Deliver due in-app reminders. Safe to retry; schedule every minute."

    def handle(self, *args, **options):
        self.stdout.write(f"Delivered {deliver_due()} notification(s).")
