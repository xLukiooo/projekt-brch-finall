from django.urls import path
from .views import HelloView, HealthCheckView, ItemListCreateView

urlpatterns = [
    path('items/', ItemListCreateView.as_view(), name='item-list-create'),
    path('hello/', HelloView.as_view(), name='hello'),
    path('health/', HealthCheckView.as_view(), name='health_check'),
]
