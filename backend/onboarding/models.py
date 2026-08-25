import uuid

from django.db import models


class StudentOnboarding(models.Model):
    """
    D1 Staged/Enforced record — mirrors the BigQuery student_onboarding
    schema in terraform/main.tf so the transactional model and the
    analytics sink never drift apart.
    """

    REGION_CHOICES = [
        ("AE", "United Arab Emirates"),
        ("IN", "India"),
        ("SA", "Saudi Arabia"),
        ("OTHER", "Other"),
    ]

    record_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    region = models.CharField(max_length=8, choices=REGION_CHOICES)
    student_name = models.CharField(max_length=120)
    guardian_email = models.EmailField(max_length=254)

    # DCYN fields — strict booleans only, no nullable "maybe" state.
    has_diagnosed_learning_difficulty = models.BooleanField()
    requires_lsa_support = models.BooleanField()
    guardian_consent_data_processing = models.BooleanField()

    ingested_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "student_onboarding"
