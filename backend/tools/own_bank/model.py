"""Constructors of the app's own tasks (see math_ru.py). Every task has a full solution."""


def _with_passage(task: dict, passage: str | None) -> dict:
    if passage:
        task["passage"] = passage  # a text shared by several tasks (reading, a source, a poem)
    return task


def S(topic: str, difficulty: str, text: str, right: str, wrong: list[str], solution: str,
      passage: str | None = None) -> dict:
    """Single choice: the right option first; the build shuffles the options."""
    return _with_passage({"type": "single", "topic": topic, "difficulty": difficulty, "text": text,
                          "options": [right, *wrong], "correct": [0], "explanation": solution}, passage)


def M(topic: str, difficulty: str, text: str, left: list[str], options: list[str], correct: list[int],
      solution: str, passage: str | None = None) -> dict:
    """Matching A–D ↔ 1–5: `correct` are option indices (from 0) for A..D."""
    return _with_passage({"type": "matching", "topic": topic, "difficulty": difficulty, "text": text, "left": left,
                          "options": options, "correct": correct, "explanation": solution}, passage)


def N(topic: str, difficulty: str, text: str, answer: str, solution: str) -> dict:
    """Open answer: a non-negative number, as on the answer sheet of the ЦВЭ."""
    return {"type": "numeric", "topic": topic, "difficulty": difficulty, "text": text, "options": [],
            "correct": answer, "explanation": solution}
