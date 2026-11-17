from django.db import migrations, models


NUMBERS = [3, 7, 14, 19, 27, 29, 32]


def seed_blocks(apps, schema_editor):
    Block = apps.get_model("accounts", "Block")
    for number in NUMBERS:
        Block.objects.get_or_create(number=number, defaults={"name": f"Block {number}", "is_active": True})


class Migration(migrations.Migration):
    dependencies = [("accounts", "0003_alter_fellowprofile_options")]
    operations = [
        migrations.AddField(model_name="block", name="number", field=models.PositiveSmallIntegerField(blank=True, choices=[(n, str(n)) for n in NUMBERS], null=True, unique=True)),
        migrations.AddField(model_name="block", name="is_active", field=models.BooleanField(default=False)),
        migrations.AlterField(model_name="block", name="name", field=models.CharField(blank=True, max_length=255, null=True)),
        migrations.AlterModelOptions(name="block", options={"ordering": ["number", "name"]}),
        migrations.AddConstraint(model_name="block", constraint=models.CheckConstraint(condition=models.Q(number__in=NUMBERS) | models.Q(number__isnull=True), name="block_canonical_number")),
        migrations.AddConstraint(model_name="block", constraint=models.CheckConstraint(condition=models.Q(is_active=False) | models.Q(number__isnull=False), name="active_block_must_be_mapped")),
        migrations.RunPython(seed_blocks, migrations.RunPython.noop),
    ]
