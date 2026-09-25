"""Check the app's lessons and build data/lessons/<subject>_<lang>.json (loaded by `python -m app.seed`).

    python -m tools.lessons.build
"""
import importlib
import json
import sys
from pathlib import Path

from tools.own_bank.build import _texts, check_translation, script_errors, shuffle_options, validate

SOURCES = [
    "tools.lessons.math_ru",
    "tools.lessons.physics_ru",
    "tools.lessons.chemistry_ru",
    "tools.lessons.biology_ru",
    "tools.lessons.geography_ru",
    "tools.lessons.history_ru",
    "tools.lessons.law_ru",
    "tools.lessons.english_ru",
    "tools.lessons.ru_lang_lit_ru",
    "tools.lessons.tj_lang_tj",
    "tools.lessons.tj_lit_tj",
]
OUT_DIR = Path(__file__).resolve().parents[2] / "data" / "lessons"
MIN_CONTENT = 600  # a summary, not a stub
MIN_PRACTICE = 5


def lesson_errors(lesson: dict, lang: str) -> list[str]:
    errors = []
    content = lesson["content"]
    if not content.startswith("# ") or "\n## " not in content:
        errors.append("content: a «# title» and at least one «## section» are required")
    if len(content) < MIN_CONTENT:
        errors.append(f"content: {len(content)} characters, at least {MIN_CONTENT} are required")
    if len(lesson["check"]) != 3:
        errors.append(f"check: 3 questions are required, not {len(lesson['check'])}")
    if len(lesson["practice"]) < MIN_PRACTICE:
        errors.append(f"practice: at least {MIN_PRACTICE} exercises are required")
    errors += script_errors([lesson["title"], content], lang)
    for kind in ("check", "practice"):
        for j, task in enumerate(lesson[kind], start=1):
            for error in validate(task) + script_errors(_texts(task), lang):
                errors.append(f"{kind} #{j}: {error}")
    return errors


def build_source(module_name: str) -> tuple[Path, dict]:
    module = importlib.import_module(module_name)
    subject, lang = module.SUBJECT, module.LANGUAGE
    topics_tj = getattr(module, "TOPICS_TJ", {})
    originals = importlib.import_module(module.TRANSLATES).LESSONS if hasattr(module, "TRANSLATES") else None
    if originals is not None and len(originals) != len(module.LESSONS):
        print(f"{module_name}: {len(module.LESSONS)} lessons, the original has {len(originals)}")
        sys.exit(1)
    failed = False
    seen_topics = set()
    records = []
    for i, lesson in enumerate(module.LESSONS, start=1):
        errors = lesson_errors(lesson, lang)
        topic = lesson["topic"]
        if originals is not None:
            # A translation names the topic in its own language; the key is the original's (Russian) title
            original = originals[i - 1]
            if topics_tj.get(original["topic"]) != topic:
                errors.append(f"topic should be TOPICS_TJ[{original['topic']!r}]")
            topic = original["topic"]
            for kind in ("check", "practice"):
                if len(lesson[kind]) != len(original[kind]):
                    errors.append(f"{kind}: {len(lesson[kind])} questions, the original has {len(original[kind])}")
                    continue
                for j, (task, orig) in enumerate(zip(lesson[kind], original[kind], strict=True), start=1):
                    errors += [f"{kind} #{j}: {e}" for e in check_translation(task, orig)]
        elif topics_tj and topic not in topics_tj:
            errors.append(f"no Tajik title in TOPICS_TJ for {topic!r}")
        if topic in seen_topics:
            errors.append("one lesson per topic")
        seen_topics.add(topic)
        if errors:
            failed = True
            print(f"{module_name} lesson #{i} ({lesson['title']}): " + "; ".join(errors))
            continue
        record = {"topic": topic, "topic_tj": topics_tj.get(topic, topic), "title": lesson["title"],
                  "content": lesson["content"]}
        for kind in ("check", "practice"):
            record[kind] = [
                shuffle_options({k: v for k, v in task.items() if k != "topic"}, f"{subject}-{lang}-{i}-{kind}{j}")
                for j, task in enumerate(lesson[kind], start=1)
            ]
        records.append(record)
    if failed:
        sys.exit(1)
    return OUT_DIR / f"{subject}_{lang}.json", {"subject": subject, "language": lang, "lessons": records}


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in SOURCES:
        path, bank = build_source(name)
        path.write_text(json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        lessons = bank["lessons"]
        exercises = sum(len(x["check"]) + len(x["practice"]) for x in lessons)
        print(f"{path.name}: {len(lessons)} lessons, {exercises} questions")


if __name__ == "__main__":
    main()
