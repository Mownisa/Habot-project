"""
DCYN (Deconstructed Clean Yes/No) library.

Purpose: the intake form collects answers to yes/no questions as free-form
strings (from a web form, so "Yes", "yes", "Y", "true", "1" all show up).
Task 3 requires eliminating human judgment entirely — so this library
accepts ONLY an explicit allow-list of representations for True/False and
raises on anything else, rather than trying to be "smart" about guessing
intent. Ambiguous input should fail validation, not be silently coerced.
"""

from rest_framework import serializers

_TRUE_VALUES = {"yes", "y", "true", "1"}
_FALSE_VALUES = {"no", "n", "false", "0"}


def to_dcyn_bool(raw_value) -> bool:
    """
    Convert a raw form answer into a strict boolean.
    Raises serializers.ValidationError for anything not on the allow-list —
    this is the "zero deviation" / "eliminate human judgment" requirement.
    """
    if isinstance(raw_value, bool):
        return raw_value

    if raw_value is None:
        raise serializers.ValidationError(
            "DCYN field cannot be null — an explicit Yes/No answer is required."
        )

    normalized = str(raw_value).strip().lower()

    if normalized in _TRUE_VALUES:
        return True
    if normalized in _FALSE_VALUES:
        return False

    raise serializers.ValidationError(
        f"DCYN field received an ambiguous value: '{raw_value}'. "
        f"Only explicit Yes/No representations are accepted — no inference is performed."
    )


class DCYNField(serializers.Field):
    """
    A DRF serializer field that wraps to_dcyn_bool, so every DCYN question
    on the onboarding form goes through the exact same deconstruction logic
    with no per-field custom parsing.
    """

    def to_internal_value(self, data):
        return to_dcyn_bool(data)

    def to_representation(self, value):
        return bool(value)
