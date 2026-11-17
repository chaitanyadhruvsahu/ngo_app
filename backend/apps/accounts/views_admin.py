from django.shortcuts import get_object_or_404
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.block_filters import filter_block
from apps.accounts.models import FellowProfile
from apps.accounts.permissions import IsAdmin
from apps.accounts.serializers import FellowProfileDetailSerializer, FellowProfileListSerializer


class _FellowListPagination(PageNumberPagination):
    page_size = 25
    page_size_query_param = "page_size"
    max_page_size = 100


class AdminFellowListView(APIView):
    """Read-only, Admin-only. No block filter yet — explicitly Phase 4
    scope (Phase 2 mandate, Assumption 3); `block` is already on every
    record for when that ships.
    """

    permission_classes = [IsAdmin]

    def get(self, request):
        fellows = filter_block(FellowProfile.objects.select_related("user", "block"), request)
        paginator = _FellowListPagination()
        page = paginator.paginate_queryset(fellows, request)
        return paginator.get_paginated_response(FellowProfileListSerializer(page, many=True).data)


class AdminFellowDetailView(APIView):
    """Read-only, Admin-only. The other authorized full-detail view
    (alongside a fellow's own `/profile/me`) — Phase 2 mandate, Definition
    of Done.
    """

    permission_classes = [IsAdmin]

    def get(self, request, fellow_id):
        fellow_profile = get_object_or_404(FellowProfile, pk=fellow_id)
        return Response(FellowProfileDetailSerializer(fellow_profile).data)
