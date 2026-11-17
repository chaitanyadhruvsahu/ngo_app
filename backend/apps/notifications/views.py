from datetime import datetime
from datetime import timezone as dt_timezone

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, serializers
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import User
from apps.accounts.permissions import IsAdmin
from apps.notifications.models import Notification, NotificationRecipientState
from apps.notifications.serializers import NotificationSerializer, RecipientSerializer


class Pagination(PageNumberPagination):
    page_size = 50


class PrivateResponseMixin:
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "private, no-store"
        return response


class AdminNotificationsView(PrivateResponseMixin, generics.ListCreateAPIView):
    permission_classes = [IsAdmin]
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    pagination_class = Pagination

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class TargetsView(PrivateResponseMixin, APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        rows = User.objects.filter(status=User.Status.ACTIVE).order_by("email").values("id", "email")
        paginator = Pagination()
        return paginator.get_paginated_response(paginator.paginate_queryset(rows, request))


class MineView(PrivateResponseMixin, generics.ListAPIView):
    serializer_class = RecipientSerializer
    pagination_class = Pagination

    def get_queryset(self):
        rows = (
            NotificationRecipientState.objects.filter(user=self.request.user)
            .select_related("notification")
            .order_by("notification__scheduled_time", "id")
        )
        month = self.request.query_params.get("month")
        if month:
            try:
                start = datetime.strptime(month, "%Y-%m").replace(tzinfo=dt_timezone.utc)
                if start.strftime("%Y-%m") != month:
                    raise ValueError
                end = (
                    start.replace(year=start.year + 1, month=1)
                    if start.month == 12
                    else start.replace(month=start.month + 1)
                )
            except (ValueError, OverflowError):
                raise serializers.ValidationError({"month": "Use YYYY-MM."}) from None
            rows = rows.filter(notification__scheduled_time__gte=start, notification__scheduled_time__lt=end)
        return rows


class RecipientActionView(PrivateResponseMixin, APIView):
    action = "read"

    @transaction.atomic
    def post(self, request, pk):
        state = get_object_or_404(
            NotificationRecipientState.objects.select_for_update().select_related("notification"),
            notification_id=pk,
            user=request.user,
        )
        now = timezone.now()
        state.read_at = state.read_at or now
        if self.action == "dismiss":
            state.dismissed_at = state.dismissed_at or now
        state.save(update_fields=["read_at", "dismissed_at"])
        return Response(RecipientSerializer(state).data)
