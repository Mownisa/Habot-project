from rest_framework import serializers

from .dcyn import DCYNField
from .models import StudentOnboarding


class StudentOnboardingSerializer(serializers.ModelSerializer):
    """
    Task 3 deliverable: deconstructs the incoming student onboarding JSON
    payload with exact field validation limits, so nothing ambiguous or
    out-of-bounds can reach D1 Staged/Enforced.

    Design choices, each tied to a specific "eliminate human judgment" rule:
      - region: closed choice set (no free-text region names)
      - student_name: hard max_length, matches the DB column exactly
      - guardian_email: DRF's built-in EmailField validation, no custom regex needed
      - the three yes/no questions: routed through DCYNField, so "maybe",
        empty string, or null are all rejected rather than defaulted
    """

    region = serializers.ChoiceField(choices=StudentOnboarding.REGION_CHOICES)
    student_name = serializers.CharField(max_length=120, allow_blank=False)
    guardian_email = serializers.EmailField(max_length=254)

    has_diagnosed_learning_difficulty = DCYNField()
    requires_lsa_support = DCYNField()
    guardian_consent_data_processing = DCYNField()

    class Meta:
        model = StudentOnboarding
        fields = [
            "record_id",
            "region",
            "student_name",
            "guardian_email",
            "has_diagnosed_learning_difficulty",
            "requires_lsa_support",
            "guardian_consent_data_processing",
            "ingested_at",
        ]
        read_only_fields = ["record_id", "ingested_at"]

    def validate(self, attrs):
        """
        Cross-field rule: consent is a hard gate. If a guardian has not
        explicitly consented to data processing, the record must not be
        created at all — this is intentionally NOT a warning, it's a reject,
        matching the "zero deviation from Golden Rules" requirement.
        """
        if not attrs.get("guardian_consent_data_processing", False):
            raise serializers.ValidationError(
                {
                    "guardian_consent_data_processing": (
                        "Record rejected: guardian consent is required before "
                        "any onboarding data can be staged."
                    )
                }
            )
        return attrs
