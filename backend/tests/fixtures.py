"""A small deterministic task bank with the shape of data/ntc_bank.json (see tools/ntc_import.py)."""
from app.seed_ntc import SUBJECTS

SINGLE_PER_SUBJECT = 30
MATCHING_PER_SUBJECT = 5
NUMERIC_PER_SUBJECT = 8
SAMPLE_PER_SUBJECT = 3


def _record(code: str, qtype: str, number: int, topic: str, sample: bool = False) -> dict:
    lang = "tj" if code in ("tj_lang", "tj_lit") else "ru"
    base = {
        "subject": code, "type": qtype, "topic": topic, "number": number, "block": 0, "sample": sample,
        "language": lang, "passage": None, "text": f"{code} {qtype} {number}", "image": None,
    }
    if qtype == "single":
        return base | {"options": ["A1", "B1", "C1", "D1"], "correct": [number % 4]}
    if qtype == "matching":
        return base | {"left": ["l1", "l2", "l3", "l4"], "options": ["r1", "r2", "r3", "r4", "r5"],
                       "correct": [1, 0, 3, 2]}
    return base | {"options": [], "correct": str(10 + number)}


def small_bank() -> dict:
    questions = []
    for code in SUBJECTS:
        questions += [_record(code, "single", n, "Тема A" if n <= 15 else "Тема B")
                      for n in range(1, SINGLE_PER_SUBJECT + 1)]
        questions += [_record(code, "matching", n, "Соответствие") for n in range(1, MATCHING_PER_SUBJECT + 1)]
        questions += [_record(code, "numeric", n, "Вычисления") for n in range(1, NUMERIC_PER_SUBJECT + 1)]
        questions += [_record(code, "single", n, "Образец субтеста", sample=True)
                      for n in range(1, SAMPLE_PER_SUBJECT + 1)]
    return {"questions": questions, "source": "test"}
