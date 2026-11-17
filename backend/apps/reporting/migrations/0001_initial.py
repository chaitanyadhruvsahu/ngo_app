import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [migrations.CreateModel(name="ExportLog", fields=[
        ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
        ("export_type", models.CharField(max_length=32, choices=[("fellow_contact_list", "Fellow contacts"), ("event_participant_list", "Event candidate roster")])),
        ("filters", models.JSONField(default=dict)),
        ("run_at", models.DateTimeField(auto_now_add=True)),
        ("run_by", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to=settings.AUTH_USER_MODEL)),
    ], options={"ordering": ["-run_at", "-id"]})]
