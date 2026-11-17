from django.db import IntegrityError, transaction
from django.http import Http404
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import FellowProfile
from apps.accounts.permissions import IsAdmin, IsFellow
from apps.core.exceptions import error_response
from apps.volunteers.models import Volunteer
from apps.volunteers.serializers import VolunteerSerializer


class VolunteerListCreateView(APIView):
    permission_classes = [IsFellow]

    def get(self, request):
        volunteers = Volunteer.objects.filter(fellow_profile=request.user.fellow_profile)
        return Response(VolunteerSerializer(volunteers, many=True).data)

    def post(self, request):
        serializer = VolunteerSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            # A savepoint, not just a try/except: on Postgres an
            # IntegrityError poisons the enclosing transaction for every
            # later query unless the failure is contained to its own
            # sub-transaction here.
            with transaction.atomic():
                serializer.save(fellow_profile=request.user.fellow_profile)
        except IntegrityError:
            # Unique (fellow_profile, phone_number) constraint — a retried
            # identical submission is a safe no-op/clear conflict, not a
            # silent duplicate (Phase 2 mandate, Reliability).
            return error_response(
                "duplicate_volunteer",
                "This fellow already has a volunteer with that phone number.",
                status.HTTP_409_CONFLICT,
            )
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class VolunteerDetailView(APIView):
    """Own records only — a valid ID belonging to another fellow returns
    404, never 403 (Phase 2 mandate, Mandate #5).
    """

    permission_classes = [IsFellow]

    def _get_own_or_404(self, request, pk):
        volunteer = get_object_or_404(Volunteer, pk=pk)
        if volunteer.fellow_profile_id != request.user.fellow_profile.id:
            raise Http404
        return volunteer

    def get(self, request, pk):
        volunteer = self._get_own_or_404(request, pk)
        return Response(VolunteerSerializer(volunteer).data)

    def patch(self, request, pk):
        volunteer = self._get_own_or_404(request, pk)
        serializer = VolunteerSerializer(volunteer, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        try:
            with transaction.atomic():
                serializer.save()
        except IntegrityError:
            return error_response(
                "duplicate_volunteer",
                "This fellow already has a volunteer with that phone number.",
                status.HTTP_409_CONFLICT,
            )
        return Response(serializer.data)

    def delete(self, request, pk):
        volunteer = self._get_own_or_404(request, pk)
        volunteer.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AdminFellowVolunteerListView(APIView):
    """Read-only, Admin-only."""

    permission_classes = [IsAdmin]

    def get(self, request, fellow_id):
        fellow_profile = get_object_or_404(FellowProfile, pk=fellow_id)
        volunteers = Volunteer.objects.filter(fellow_profile=fellow_profile)
        return Response(VolunteerSerializer(volunteers, many=True).data)
