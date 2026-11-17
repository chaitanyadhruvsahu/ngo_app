from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Block
from apps.accounts.permissions import IsFellow
from apps.accounts.serializers import BlockSerializer, FellowProfileDetailSerializer


class BlockListView(APIView):
    """Read-only list of every Block — lets a fellow pick one on their own
    profile (Phase 2 mandate pass 3, §3: fellow-picks-at-onboarding is the
    default pending the NGO's actual answer on block assignment). Open to
    both roles: Admin will also need this once block-filtered browsing
    ships in Phase 4.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(BlockSerializer(Block.objects.filter(is_active=True), many=True).data)


class ProfileMeView(APIView):
    """Own profile only — the single authorized full-detail view for a
    fellow (Phase 2 mandate, Definition of Done).
    """

    permission_classes = [IsFellow]

    def get(self, request):
        return Response(FellowProfileDetailSerializer(request.user.fellow_profile).data)

    def patch(self, request):
        serializer = FellowProfileDetailSerializer(
            request.user.fellow_profile, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
