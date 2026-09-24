from datetime import date, datetime, timezone

from app.models import User
from app.services import gamification as g


def test_points_for_answer_base_and_streak():
    assert g.points_for_answer(False, 10, 0) == (0, 0)
    assert g.points_for_answer(True, 0) == (10, 0)
    assert g.points_for_answer(True, 4) == (10, 0)
    # after 5 correct in a row the next correct answer is worth x1.5
    assert g.points_for_answer(True, 5) == (10, 5)
    assert g.points_for_answer(True, 12) == (10, 5)
    # official points: open answer = 2, matching = 1 per pair (partial answers still earn points)
    assert g.points_for_answer(True, 0, 2) == (20, 0)
    assert g.points_for_answer(False, 7, 3) == (30, 0)
    assert g.points_for_answer(True, 5, 4) == (40, 20)


def test_subtest_scaling_to_500():
    # Tajik language: 40 points → 75, a main subject 20/40 → half of 175
    assert g.scale_subtest(40, 40, 75) == 75
    assert g.scale_subtest(20, 40, 175) == 87.5
    assert g.scale_subtest(0, 0, 100) == 0
    subtests = [{"score": 75}, {"score": 175}, {"score": 100}, {"score": 150}]
    assert g.estimate_mmt_score(subtests) == 500 == g.MMT_MAX


def test_levels():
    assert g.level_for_points(0)["code"] == "novice"
    assert g.level_for_points(499)["code"] == "novice"
    assert g.level_for_points(500)["code"] == "learner"
    assert g.level_for_points(2000)["number"] == 3
    top = g.level_for_points(50_000)
    assert top["code"] == "master" and top["next_level_points"] is None and top["progress"] == 1.0
    assert g.level_for_points(1250)["progress"] == 0.5


def _at(y, m, d, hour=12):
    return datetime(y, m, d, hour, tzinfo=timezone.utc)


def test_daily_streak():
    user = User(name="x", current_streak=0, longest_streak=0)
    g.register_activity(user, _at(2026, 9, 1))
    assert user.current_streak == 1
    g.register_activity(user, _at(2026, 9, 1, 15))  # same day
    assert user.current_streak == 1
    g.register_activity(user, _at(2026, 9, 2))
    g.register_activity(user, _at(2026, 9, 3))
    assert user.current_streak == 3 and user.longest_streak == 3
    g.register_activity(user, _at(2026, 9, 5))  # skipped a day
    assert user.current_streak == 1 and user.longest_streak == 3


def test_streak_uses_local_timezone():
    user = User(name="x", current_streak=0, longest_streak=0)
    # 20:00 UTC on Sep 1 is already Sep 2 in Dushanbe (UTC+5)
    g.register_activity(user, _at(2026, 9, 1, 20))
    assert user.last_activity_date == date(2026, 9, 2)
