from django.db.models import Count, Q, Sum
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import serializers
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.block_filters import block_number, filter_block
from apps.accounts.models import Block, FellowProfile
from apps.accounts.permissions import IsAdmin
from apps.jobs.models import Job, JobSubmission
from apps.reporting.models import ExportLog
from apps.reporting.xlsx import workbook
from apps.volunteers.models import Volunteer


class Pagination(PageNumberPagination):
    page_size = 25
    page_size_query_param = "page_size"
    max_page_size = 100


def private(response):
    response["Cache-Control"] = "private, no-store"
    return response


class AdminVolunteerListView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        rows = filter_block(Volunteer.objects.all(), request, "fellow_profile__block")
        paginator = Pagination()
        page = paginator.paginate_queryset(
            rows.values(
                "id",
                "full_name",
                "phone_number",
                "fellow_profile_id",
                "fellow_profile__full_name",
                "fellow_profile__block__number",
            ),
            request,
        )
        return private(
            paginator.get_paginated_response(
                [
                    {
                        "id": row["id"],
                        "full_name": row["full_name"],
                        "phone_number": row["phone_number"],
                        "fellow_id": row["fellow_profile_id"],
                        "fellow_name": row["fellow_profile__full_name"],
                        "block_number": row["fellow_profile__block__number"],
                    }
                    for row in page
                ]
            )
        )


class ExportHistoryView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        paginator = Pagination()
        page = paginator.paginate_queryset(
            ExportLog.objects.filter(run_by=request.user).values("id", "export_type", "filters", "run_at"),
            request,
        )
        return private(paginator.get_paginated_response(page))


class ExportView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request, export_type):
        serializers.ChoiceField(choices=ExportLog.Type.values).run_validation(export_type)
        number = block_number(request)
        if export_type == ExportLog.Type.FELLOW_CONTACT_LIST:
            headers = ["Fellow ID", "Name", "Email", "Phone", "Block"]
            rows = filter_block(FellowProfile.objects.all(), request).values_list(
                "id", "full_name", "user__email", "phone_number", "block__number"
            )
        else:
            headers = ["Volunteer ID", "Name", "Phone", "Fellow", "Block", "Participation status"]
            selected = filter_block(Volunteer.objects.all(), request, "fellow_profile__block").values_list(
                "id",
                "full_name",
                "phone_number",
                "fellow_profile__full_name",
                "fellow_profile__block__number",
            )
            rows = [(*row, "Candidate — attendance not recorded") for row in selected]
        content = workbook(headers, rows)
        # A log failure must prevent delivery. A validation/generation failure
        # has not generated a deliverable and deliberately has no success log.
        ExportLog.objects.create(
            run_by=request.user, export_type=export_type, filters={} if number is None else {"block": number}
        )
        response = HttpResponse(
            content, content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        filename = "event_candidate_roster" if export_type == "event_participant_list" else export_type
        response["Content-Disposition"] = f'attachment; filename="{filename}.xlsx"'
        response["X-Content-Type-Options"] = "nosniff"
        return private(response)


def aggregates(jobs, submissions):
    job_data = jobs.aggregate(job_count=Count("id"), expected_hours=Sum("expected_hours"))
    submission_data = submissions.aggregate(
        submission_count=Count("id"),
        approval_count=Count("id", filter=Q(review_status="approved")),
        approved_hours=Sum("actual_hours", filter=Q(review_status="approved")),
    )
    data = {**job_data, **submission_data}
    for field in ("expected_hours", "approved_hours"):
        data[field] = format(data[field] or 0, ".2f")
    return data


class BlockDashboardView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        results = []
        for block in Block.objects.filter(is_active=True):
            results.append(
                {
                    "block_number": block.number,
                    "fellow_count": FellowProfile.objects.filter(block=block).count(),
                    **aggregates(
                        Job.objects.filter(assigned_to__block=block),
                        JobSubmission.objects.filter(submitted_by__fellow_profile__block=block),
                    ),
                }
            )
        return private(Response({"results": results}))


class FellowDashboardView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request, fellow_id):
        fellow = get_object_or_404(FellowProfile.objects.only("id", "user_id", "full_name"), pk=fellow_id)
        return private(
            Response(
                {
                    "fellow_id": fellow.id,
                    "full_name": fellow.full_name,
                    **aggregates(
                        Job.objects.filter(assigned_to=fellow),
                        JobSubmission.objects.filter(submitted_by_id=fellow.user_id),
                    ),
                }
            )
        )
