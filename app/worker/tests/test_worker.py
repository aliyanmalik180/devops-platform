from worker import parse_event


def test_parse_valid():
    assert parse_event(b"abc1234") == "abc1234"


def test_parse_invalid():
    assert parse_event(b"bad code!") is None
    assert parse_event("") is None
