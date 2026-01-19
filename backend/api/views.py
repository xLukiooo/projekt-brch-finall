from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.generics import ListCreateAPIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny

from .models import Item
from .serializers import ItemSerializer


class ItemListCreateView(ListCreateAPIView):
    serializer_class = ItemSerializer
    queryset = Item.objects.all()


class HelloView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        print("HELLO request.user dict:", getattr(request.user, '__dict__', {}))
        return Response({"message": "Hello from Django!"}, status=status.HTTP_200_OK)

class HealthCheckView(APIView):
    """
    Widok dla health checka Application Load Balancera.
    Zwraca prostą odpowiedź HTTP 200 OK.
    """
    permission_classes = [AllowAny] 

    def get(self, request):
        return HttpResponse(status=200)