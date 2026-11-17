from rest_framework import serializers

from apps.accounts.models import Block


def block_number(request):
    value = request.query_params.get("block")
    if value is None:
        return None
    return serializers.ChoiceField(choices=Block.Number.values).run_validation(value)


def filter_block(rows, request, relation="block"):
    number = block_number(request)
    if number is not None:
        rows = rows.filter(**{f"{relation}__number": number, f"{relation}__is_active": True})
    return rows
