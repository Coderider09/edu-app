"""Lessons written for EduApp: a topic's summary in Markdown, a 3-question mini-check and practice exercises.

Questions use the task format of tools/own_bank (single / matching / numeric), without a topic of their own:
they belong to the lesson's topic.
"""
from tools.own_bank.model import M, N, S


def L(topic: str, title: str, content: str, check: list[dict], practice: list[dict]) -> dict:
    """One lesson: `topic` is the Russian topic title (the key shared by translations)."""
    return {"topic": topic, "title": title, "content": content.strip() + "\n", "check": check,
            "practice": practice}


def s(difficulty: str, text: str, right: str, wrong: list[str], solution: str, passage: str | None = None) -> dict:
    return S("-", difficulty, text, right, wrong, solution, passage)


def m(difficulty: str, text: str, left: list[str], options: list[str], correct: list[int], solution: str) -> dict:
    return M("-", difficulty, text, left, options, correct, solution)


def n(difficulty: str, text: str, answer: str, solution: str) -> dict:
    return N("-", difficulty, text, answer, solution)
