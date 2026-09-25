"""Check the app's own tasks and build data/own/<subject>_<lang>.json (loaded by `python -m app.seed`).

    python -m tools.own_bank.build
"""
import importlib
import json
import random
import re
import sys
from collections import Counter
from pathlib import Path

SOURCES = [
    "tools.own_bank.math_ru",
    "tools.own_bank.physics_ru",
    "tools.own_bank.chemistry_ru",
    "tools.own_bank.biology_ru",
    "tools.own_bank.geography_ru",
    "tools.own_bank.history_ru",
    "tools.own_bank.law_ru",
    "tools.own_bank.english_ru",
    "tools.own_bank.ru_lang_lit_ru",
    "tools.own_bank.tj_lang_tj",
    "tools.own_bank.tj_lit_tj",
    # Tajik versions (translations checked against the Russian originals)
    "tools.own_bank.math_tj",
    "tools.own_bank.physics_tj",
    "tools.own_bank.chemistry_tj",
    "tools.own_bank.biology_tj",
    "tools.own_bank.geography_tj",
    "tools.own_bank.history_tj",
    "tools.own_bank.law_tj",
]
OUT_DIR = Path(__file__).resolve().parents[2] / "data" / "own"
DIFFICULTIES = {"easy", "medium", "hard"}
NUMERIC = re.compile(r"^\d{1,9}([.,]\d{1,4})?$")  # what the answer field accepts (app and API)
# Letters of other Cyrillic alphabets that look like Tajik ones (қ/ќ, ҳ/њ, ӯ/ў…) — typos in Tajik texts
FOREIGN_CYRILLIC = re.compile("[ќњљђћџѓѕјЎўІіЇїЄєҐґӘәЦцЩщЫыЬь]")  # Ц, Щ, Ы, Ь are not in the Tajik alphabet
# A word mixing Cyrillic and Latin letters («дардnok», «сoль» with a Latin «o»)
MIXED_WORD = re.compile(r"\b(?=\w*[а-яёӣӯқғҳҷ])(?=\w*[a-z])\w+\b", re.IGNORECASE)


def _texts(task: dict) -> list[str]:
    return [task["text"], task["explanation"], task.get("passage") or "", *task["options"], *(task.get("left") or [])]


def check_translation(task: dict, original: dict) -> list[str]:
    """A translated task must keep the original's type, topic, difficulty and answer key."""
    errors = []
    for key in ("type", "difficulty"):
        if task[key] != original[key]:
            errors.append(f"{key} differs from the original ({original[key]!r})")
    if task["type"] == original["type"]:
        if task["type"] != "single" and task["correct"] != original["correct"]:
            errors.append(f"answer differs from the original ({original['correct']!r})")
        if task["type"] == "matching" and len(task["options"]) != len(original["options"]):
            errors.append("matching: another number of options than in the original")
    return errors


def validate(task: dict) -> list[str]:
    errors = []
    if task["difficulty"] not in DIFFICULTIES:
        errors.append(f"difficulty {task['difficulty']!r}")
    if not task["text"].strip() or not task["topic"].strip():
        errors.append("empty text or topic")
    if len(task["explanation"].strip()) < 20:
        errors.append("no solution")
    options = task["options"]
    if task["type"] == "single":
        if len(options) != 4 or len(set(options)) != 4 or not all(o.strip() for o in options):
            errors.append("single: 4 different options are required")
    elif task["type"] == "matching":
        correct = task["correct"]
        if len(task["left"]) != 4 or len(options) != 5 or len(set(options)) != 5:
            errors.append("matching: 4 items on the left and 5 different options are required")
        if len(correct) != 4 or len(set(correct)) != 4 or not all(0 <= c < len(options) for c in correct):
            errors.append("matching: 4 different option indices are required")
    elif not NUMERIC.match(task["correct"]):
        errors.append(f"numeric answer {task['correct']!r} can't be typed on the answer sheet")
    return errors


def build_source(module_name: str) -> tuple[Path, list[dict]]:
    module = importlib.import_module(module_name)
    subject, lang = module.SUBJECT, module.LANGUAGE
    # A translation (e.g. math_tj of math_ru) goes to the same topics: topic keys stay in Russian
    originals = importlib.import_module(module.TRANSLATES).TASKS if hasattr(module, "TRANSLATES") else None
    topics_tj = getattr(module, "TOPICS_TJ", None)
    if originals is not None and len(originals) != len(module.TASKS):
        print(f"{module_name}: {len(module.TASKS)} tasks, the original has {len(originals)}")
        sys.exit(1)
    seen_texts = set()
    counters: Counter = Counter()
    records = []
    failed = False
    for i, task in enumerate(module.TASKS, start=1):
        errors = validate(task)
        if lang == "tj" and any(FOREIGN_CYRILLIC.search(t) for t in _texts(task)):
            errors.append("letters of another Cyrillic alphabet: " + ", ".join(
                sorted({m for t in _texts(task) for m in FOREIGN_CYRILLIC.findall(t)})))
        mixed = sorted({w for t in _texts(task) for w in MIXED_WORD.findall(t)})
        if mixed:
            errors.append("Cyrillic and Latin letters in one word: " + ", ".join(mixed))
        topic_tj = None
        if originals is not None:
            original = originals[i - 1]
            errors += check_translation(task, original)
            topic_tj = task["topic"]
            if topics_tj.get(original["topic"]) != topic_tj:
                errors.append(f"topic should be TOPICS_TJ[{original['topic']!r}]")
            task = {**task, "topic": original["topic"]}
        if task["text"] in seen_texts:
            errors.append("duplicate text")
        seen_texts.add(task["text"])
        if errors:
            failed = True
            print(f"{module_name} #{i} ({task['text'][:50]}…): {'; '.join(errors)}")
            continue
        counters[task["type"]] += 1
        record = {"subject": subject, "language": lang, "number": counters[task["type"]], **task}
        if topic_tj:
            record["topic_tj"] = topic_tj
        if task["type"] == "single":
            # Deterministic shuffle: the right answer is not always «A», and rebuilding changes nothing
            options = list(task["options"])
            random.Random(f"{subject}-{lang}-{record['number']}").shuffle(options)
            record["options"] = options
            record["correct"] = [options.index(task["options"][0])]
        elif task["type"] == "matching":
            # The same for the right column: the answer pattern shouldn't repeat from task to task
            order = list(range(len(task["options"])))
            random.Random(f"{subject}-{lang}-m{record['number']}").shuffle(order)
            record["options"] = [task["options"][i] for i in order]
            record["correct"] = [order.index(c) for c in task["correct"]]
        records.append(record)
    if failed:
        sys.exit(1)
    return OUT_DIR / f"{subject}_{lang}.json", records


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in SOURCES:
        path, records = build_source(name)
        path.write_text(
            json.dumps({"source": "EduApp", "questions": records}, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8",
        )
        types = Counter(r["type"] for r in records)
        letters = Counter("ABCD"[r["correct"][0]] for r in records if r["type"] == "single")
        print(f"{path.name}: {len(records)} tasks {dict(types)}, right answers {dict(sorted(letters.items()))}")


if __name__ == "__main__":
    main()
