from rest_framework import serializers
from .models import Item

class ItemSerializer(serializers.ModelSerializer):
    """
    Serializer dla modelu Item.
    """
    class Meta:
        model = Item
        fields = ['id', 'name', 'created_at']
