import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("notifications", "0001_initial"), ("jobs", "0001_initial")]
    operations = [
        migrations.AddField(model_name="notification", name="source_job", field=models.ForeignKey(
            null=True, blank=True, on_delete=django.db.models.deletion.PROTECT, to="jobs.job")),
        migrations.AddField(model_name="notification", name="automation_key", field=models.CharField(
            max_length=200, null=True, blank=True, unique=True)),
        migrations.AddField(model_name="notification", name="cancelled_at", field=models.DateTimeField(
            null=True, blank=True)),
    ]
