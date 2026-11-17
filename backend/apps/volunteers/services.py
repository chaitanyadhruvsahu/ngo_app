import phonenumbers
from phonenumbers import NumberParseException


class InvalidPhoneNumber(Exception):
    pass


def normalize_phone_number(raw: str, default_region: str = "IN") -> str:
    """Returns the E.164 form (e.g. +919876543210). `default_region`
    assumes India since the master doc's phone numbers are for an Indian
    NGO's fellows/volunteers; a number already in +<country> form parses
    regardless of the default region.
    """
    try:
        parsed = phonenumbers.parse(raw, default_region)
    except NumberParseException as exc:
        raise InvalidPhoneNumber(f"'{raw}' is not a valid phone number.") from exc

    if not phonenumbers.is_valid_number(parsed):
        raise InvalidPhoneNumber(f"'{raw}' is not a valid phone number.")

    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
