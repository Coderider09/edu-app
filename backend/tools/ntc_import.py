"""Import the official typical test tasks (ЦВЭ, component A) of the National Testing Center (ntc.tj).

Source: https://ntc.tj/ru/abiturientu/tipovye-testovye-zadaniya.html — the collections are published
by the Center for free ("БЕСПЛАТНО! На сайте www.ntc.tj") together with answer keys.

What it does:
  1. downloads every subject collection + its key into data/ntc/pdf (cached);
  2. parses tasks of the three official types — single choice (A–D), matching (A–D ↔ 1–5) and
     open (natural number) — with their topics, and the "образец субтеста" (sample subtest);
  3. tasks whose text cannot be extracted reliably (formulas, figures, tables) are also rendered to
     an image cropped from the PDF (app/static/ntc/...), so nothing is lost;
  4. writes data/ntc_bank.json that `python -m app.seed` loads into the database.

Usage:  python -m tools.ntc_import [--subjects math,physics] [--no-download]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import pdfplumber
import pypdf
import requests
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PDF_DIR = ROOT / "data" / "ntc" / "pdf"
STATIC_DIR = ROOT / "app" / "static" / "ntc"
BANK_PATH = ROOT / "data" / "ntc_bank.json"
BASE_URL = "https://ntc.tj/images/Downloads/"
SOURCE_PAGE = "https://ntc.tj/ru/abiturientu/tipovye-testovye-zadaniya.html"

# code -> (tasks pdf, key pdf, language of the tasks)
SUBJECT_FILES = {
    "tj_lang": ("A1-ALL_Tj.pdf", "keys_2026/A1-ALL_Tj_key.pdf", "tj"),
    "math": ("A2-12_Math_ru.pdf", "keys_2026/A2-12_Math_ru.pdf", "ru"),
    "history": ("A2-34_History_ru.pdf", "keys_2026/A2-34_History_ru_key.pdf", "ru"),
    "biology": ("A2-5_Biology_ru.pdf", "keys_2026/A2-5_Biology_ru.pdf", "ru"),
    "chemistry": ("A3-15_Chemistry_ru.pdf", "keys_2026/A3-15_Chemistry_ru_key.pdf", "ru"),
    "geography": ("A3-2_Geography_ru.pdf", "keys_2026/A3-2_Geography_ru_key.pdf", "ru"),
    "ru_lang_lit": ("A3-3_RusLngLiterature_ru.pdf", "keys_2026/A3-3_RuLiterature_ru_key.pdf", "ru"),
    "tj_lit": ("A3-3_TjLiterature_tj.pdf", "keys_2026/A3-3_TjLiterature_tj_key.pdf", "tj"),
    "law": ("A3-4_Law_ru.pdf", "keys_2026/A3-4_Law_ru_key.pdf", "ru"),
    "physics": ("A4-15_Physics_ru.pdf", "keys_2026/A4-15_Physics_ru_key.pdf", "ru"),
    "english": ("A4-234_En.pdf", "keys_2026/A4-234_En_key_ru.pdf", "ru"),
}

SINGLE, MATCHING, NUMERIC = "single", "matching", "numeric"
LETTERS = {"А": 0, "A": 0, "а": 0, "a": 0, "В": 1, "B": 1, "в": 1, "b": 1, "С": 2, "C": 2, "с": 2, "c": 2,
           "D": 3, "d": 3, "Д": 3}

RE_SAMPLE = re.compile(r"^(О ?БРАЗЕЦ СУБТЕСТА|Н ?АМУНАИ СУБТЕСТИ|С ?УБТЕСТ ПО\s)")
RE_SINGLE = re.compile(r"(С ВЫБОРОМ|ИНТИХОБИ ЯК)")
RE_MATCH = re.compile(r"(СООТВЕТСТВ|МУВОФИҚАТ)")
RE_OPEN = re.compile(r"(ОТКРЫТОГО ТИПА|КУШОДА)")
RE_NOISE = re.compile(
    r"(Саҳ\.\s*/\s*Стр\.|БЕСПЛАТНО|www\.ntc\.tj|Страница\s+\d+|Саҳифаи?\s*\d+|ЦВЭ[\s-]*20\d\d\s*$|ИМД[\s-]*20\d\d)"
)
RE_OPTION = re.compile(r"^([АВСDABCабсdabc])\)\s*(.*)$")
RE_RIGHT = re.compile(r"^([1-5])\)\s*(.*)$")
RE_ANSWER_LINE = re.compile(r"^(Ответ|Ҷавоб|Answer)\s*:?\s*$", re.I)

# Characters that render correctly as plain text; anything else (unmapped glyphs, math alphanumerics,
# symbol-font artefacts) means the task is shown as an image.
ALLOWED = re.compile(
    r"^[\s\w.,;:!?()\[\]{}«»\"'`’‘“”„\-–—−+*/=<>≤≥≈≠±×·∙÷%‰°№§&#@^_|~…•√∞∠⊥∥△°"
    r"Ͱ-ϿЀ-ӿ⁰-₟←-⇿∀-⋿²³¹¼-¾]*$"
)


@dataclass
class Line:
    page: int
    top: float
    bottom: float
    x0: float
    words: list  # [(x0, x1, text)]

    @property
    def text(self) -> str:
        parts: list[str] = []
        prev_x1 = None
        for x0, x1, word in self.words:
            if prev_x1 is not None and x0 - prev_x1 > 0.9:
                parts.append(" ")
            parts.append(word)
            prev_x1 = x1
        return "".join(parts).strip()


@dataclass
class Task:
    subject: str
    kind: str
    block: int
    number: int
    topic: str
    stem: list = field(default_factory=list)          # lines of the question
    options: list = field(default_factory=list)       # single: 4 texts / matching: right items (5)
    left: list = field(default_factory=list)          # matching: left items (4)
    passage: Optional[str] = None
    lines: list = field(default_factory=list)         # Line objects (for cropping)
    sample: bool = False
    answer: object = None
    image: Optional[str] = None
    has_figure: bool = False
    open_answer: bool = False
    start: tuple = (0, 0.0)                           # (page, top) of the task
    end: Optional[tuple] = None                       # (page, top) where the next block starts


# ---------------------------------------------------------------- download
def download(path: str, force: bool = False) -> Path:
    dest = PDF_DIR / path.replace("/", "__")
    if dest.exists() and dest.stat().st_size > 0 and not force:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    url = BASE_URL + path
    for attempt in range(5):
        try:
            done = dest.stat().st_size if dest.exists() else 0
            headers = {"Range": f"bytes={done}-"} if done else {}
            with requests.get(url, stream=True, timeout=60, headers=headers) as r:
                if r.status_code == 416:
                    return dest
                r.raise_for_status()
                mode = "ab" if r.status_code == 206 else "wb"
                with open(dest, mode) as f:
                    for chunk in r.iter_content(1 << 16):
                        f.write(chunk)
            with open(dest, "rb") as f:
                f.seek(-2048, 2)
                if b"%%EOF" in f.read():
                    return dest
        except requests.RequestException as exc:
            print(f"  retry {attempt + 1} {path}: {exc}")
            time.sleep(3)
    raise RuntimeError(f"Cannot download {url}")


# ---------------------------------------------------------------- text lines
def is_watermark(obj) -> bool:
    return obj.get("object_type") == "char" and (abs(obj["matrix"][1]) > 0.01 or obj.get("size", 0) > 30)


def page_lines(page, page_no: int) -> list[Line]:
    clean = page.filter(lambda o: not is_watermark(o))
    words = clean.extract_words(keep_blank_chars=False, use_text_flow=False, extra_attrs=["size"])
    words.sort(key=lambda w: (round(w["top"] / 3), w["x0"]))
    lines: list[Line] = []
    for w in words:
        if lines and abs(lines[-1].top - w["top"]) < 3.5:
            ln = lines[-1]
            ln.words.append((w["x0"], w["x1"], w["text"]))
            ln.bottom = max(ln.bottom, w["bottom"])
            ln.x0 = min(ln.x0, w["x0"])
        else:
            lines.append(Line(page_no, w["top"], w["bottom"], w["x0"], [(w["x0"], w["x1"], w["text"])]))
    for ln in lines:
        ln.words.sort(key=lambda t: t[0])
    return lines


def is_upper_header(text: str) -> bool:
    letters = [c for c in text if c.isalpha()]
    if len(letters) < 4 or text[:1].isdigit():
        return False
    upper = sum(1 for c in letters if c.isupper())
    return upper / len(letters) > 0.92 and not RE_OPTION.match(text)


def clean_text(s: str) -> str:
    s = s.replace(" ", " ")
    s = re.sub(r"\(cid:\d+\)", "�", s)
    # Math italic/bold letters and digits (U+1D400-1D7FF) -> plain ones
    s = "".join(unicodedata.normalize("NFKC", c) if 0x1D400 <= ord(c) <= 0x1D7FF else c for c in s)
    return re.sub(r"[ 	]+", " ", s).strip()


def format_topic(text: str) -> str:
    """'П ЛАНИМЕТРИЯ' / 'ПЛАНИМЕТРИЯ' -> 'Планиметрия' (drop caps are extracted as a separate word)."""
    text = re.sub(r"^(\w) (\w{2,})", lambda m: m.group(1) + m.group(2), text.strip())
    if text.isupper():
        text = text[:1].upper() + text[1:].lower()
    return re.sub(r"(?<!\w)(таджикистан|тоҷикистон)", lambda m: m.group(1).capitalize(), text)


FIGURE_WORDS = re.compile(r"(рисун|график|изображ|диаграмм|схем|таблиц|расм|ҷадвал|нақша)", re.I)


def is_clean(s: str) -> bool:
    return "�" not in s and bool(ALLOWED.match(s))


# ---------------------------------------------------------------- tasks parsing
def parse_tasks(subject: str, pdf_path: Path) -> list[Task]:
    tasks: list[Task] = []
    kind = None
    topic = ""
    block_counter = {SINGLE: -1, MATCHING: -1, NUMERIC: -1}
    expected = 1
    current: Optional[Task] = None
    passage_lines: list[str] = []
    passage: Optional[str] = None
    in_sample = False

    def close(at: tuple) -> None:
        if current is not None and current.end is None:
            current.end = at

    with pdfplumber.open(pdf_path) as pdf:
        for page_no, page in enumerate(pdf.pages):
            figures = [(im["top"], im["bottom"]) for im in page.images if (im["bottom"] - im["top"]) > 12]
            figures += [(c["top"], c["bottom"]) for c in page.curves if (c["bottom"] - c["top"]) > 8]
            for ln in page_lines(page, page_no):
                text = clean_text(ln.text)
                if not text or RE_NOISE.search(text) or ln.top < 40 or ln.top > 805:
                    continue
                if RE_SAMPLE.match(text):
                    close((page_no, ln.top))
                    in_sample, kind, expected, current, passage = True, None, 1, None, None
                    topic = "Образец субтеста"
                    continue
                header_kind = None
                if is_upper_header(text):
                    if RE_MATCH.search(text):
                        header_kind = MATCHING
                    elif RE_OPEN.search(text):
                        header_kind = NUMERIC
                    elif RE_SINGLE.search(text) or re.search(r"ЗАДАНИЯ ПО|САВОЛҲОИ ТЕСТ|САВОЛУ МАСЪАЛАҲО", text):
                        header_kind = SINGLE
                    if header_kind:
                        sub = re.search(r"\(([^)]+)\)", text)
                        if sub and not in_sample:
                            topic = format_topic(sub.group(1))
                        if header_kind != kind and not in_sample:
                            kind = header_kind
                            expected = 1
                        elif in_sample:
                            kind = header_kind
                        close((page_no, ln.top))
                        current, passage, passage_lines = None, None, []
                        continue
                    between_tasks = current is None or bool(current.options or current.left or current.open_answer)
                    if not in_sample and between_tasks and len(text) < 120 and not RE_OPTION.match(text):
                        if not re.match(r"^(ТЕСТОВЫЕ ЗАДАНИЯ|САВОЛУ МАСЪАЛАҲО|САВОЛҲОИ ТЕСТ)", text):
                            topic = format_topic(text)
                        close((page_no, ln.top))
                        current, passage, passage_lines = None, None, []
                        continue

                first = ln.words[0][2]
                m_num = re.match(r"^(\d{1,3})\.?$", first)
                num = int(m_num.group(1)) if m_num else None
                starts_task = (
                    num is not None and ln.x0 < 80 and expected <= num <= expected + 3
                    and (kind is not None or in_sample)
                )
                if in_sample and num is not None and ln.x0 < 80 and num == expected:
                    starts_task = True
                # numbering restarts at 1 → a new block (next section, or next reading passage)
                restart = not in_sample and kind is not None and num == 1 and ln.x0 < 80 and expected > 1
                if restart:
                    starts_task = True
                if starts_task and not in_sample and (num == 1 or block_counter[kind or SINGLE] < 0):
                    block_counter[kind or SINGLE] += 1
                if starts_task:
                    if passage_lines and (current is None or current.options or current.left):
                        text_block = "\n".join(passage_lines).strip()
                        passage = text_block if len(text_block) >= 200 else passage
                    passage_lines = []
                    close((page_no, ln.top))
                    current = Task(subject, kind or SINGLE, block_counter.get(kind or SINGLE, 0), num, topic,
                                   sample=in_sample, start=(page_no, ln.top))
                    current.passage = passage
                    rest = clean_text(" ".join(w[2] for w in ln.words[1:]))
                    if rest:
                        current.stem.append(rest)
                    if FIGURE_WORDS.search(rest):
                        current.has_figure = True
                    current.lines.append(ln)
                    tasks.append(current)
                    expected = num + 1
                    continue
                if current is None:
                    if kind is not None:
                        passage_lines.append(text)
                    continue

                # inside a task
                if any(t <= ln.bottom and b >= ln.top for t, b in figures) or (
                    not current.options and FIGURE_WORDS.search(text)
                ):
                    current.has_figure = True
                if RE_ANSWER_LINE.match(text) or re.match(r"^(Ответ|Ҷавоб)\s*:", text):
                    current.open_answer = True
                    current.lines.append(ln)
                    continue
                opt = RE_OPTION.match(text)
                right_x = _right_column_x(ln)
                if opt and right_x is not None:
                    # matching row: "А) left ... 1) right"
                    left_words = [w for w in ln.words if w[0] < right_x - 1]
                    right_words = [w for w in ln.words if w[0] >= right_x - 1]
                    current.kind = MATCHING if current.kind != MATCHING and not current.sample else current.kind
                    lt = clean_text(" ".join(w[2] for w in left_words))
                    rt = clean_text(" ".join(w[2] for w in right_words))
                    current.left.append(RE_OPTION.match(lt).group(2) if RE_OPTION.match(lt) else lt)
                    current.options.append(RE_RIGHT.match(rt).group(2) if RE_RIGHT.match(rt) else rt)
                    current.lines.append(ln)
                    continue
                if RE_RIGHT.match(text) and current.left:
                    current.options.append(RE_RIGHT.match(text).group(2))
                    current.lines.append(ln)
                    continue
                if opt:
                    # several options may share one line: "А) 1  В) 2"
                    parts = re.split(r"\s(?=[АВСDABCD]\)\s)", text)
                    for part in parts:
                        mo = RE_OPTION.match(part.strip())
                        if mo:
                            current.options.append(mo.group(2).strip())
                    current.lines.append(ln)
                    continue
                if current.options or current.left:
                    if current.left and ln.x0 > 200 and current.options:
                        current.options[-1] = (current.options[-1] + " " + text).strip()
                        current.lines.append(ln)
                    elif current.kind == SINGLE and len(current.options) < 4 or (
                        current.left and (len(current.left) < 4 or (85 < ln.x0 < 200 and len(current.options) <= 5))
                    ):
                        target = current.left if current.left else current.options
                        target[-1] = (target[-1] + " " + text).strip()
                        current.lines.append(ln)
                    elif current.kind == SINGLE and len(current.options) == 4 and ln.x0 > 85 and ln.x0 < 120 \
                            and not is_upper_header(text):
                        current.options[-1] = (current.options[-1] + " " + text).strip()
                        current.lines.append(ln)
                    else:
                        passage_lines.append(text)  # text between tasks → shared passage for the next ones
                else:
                    current.stem.append(text)
                    current.lines.append(ln)
    for t in tasks:
        if t.sample and t.left:
            t.kind = MATCHING
        elif t.sample and t.open_answer and not t.options:
            t.kind = NUMERIC
    return tasks


def _right_column_x(ln: Line) -> Optional[float]:
    """x of a "1)".."5)" token that starts a right column in a matching row."""
    for x0, _x1, text in ln.words[1:]:
        if re.match(r"^[1-5]\)$", text) and x0 > 200:
            return x0
    return None


# ---------------------------------------------------------------- keys
def parse_keys(pdf_path: Path) -> dict:
    """Returns {"main": {kind: [ {number: answer} per block ]}, "sample": {number: raw tokens}}."""
    # pypdf keeps one key entry per line (pdfplumber merges the columns)
    text = "\n".join((p.extract_text() or "") for p in pypdf.PdfReader(str(pdf_path)).pages)
    main = {SINGLE: [], MATCHING: [], NUMERIC: []}
    sample: dict[int, list[str]] = {}
    kind = None
    in_sample = False
    last_number = {SINGLE: 0, MATCHING: 0, NUMERIC: 0}
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        up = line.upper()
        if RE_SAMPLE.search(up) or "ОБРАЗЕЦ" in up or "НАМУНАИ СУБТЕСТ" in up:
            in_sample = True
            continue
        if not in_sample:
            if RE_MATCH.search(up) and not re.match(r"^\d", line):
                kind = MATCHING
                continue
            if RE_OPEN.search(up) and not re.match(r"^\d", line):
                kind = NUMERIC
                continue
            if (RE_SINGLE.search(up) or "ВЫБОР" in up or up.startswith("ЗАДАНИЯ ПО")) \
                    and not re.match(r"^\d", line):
                kind = SINGLE
                continue
            if kind is None:
                continue
            def slot(n: int, kind: str = kind) -> dict:
                # a new block starts when numbering restarts at 1 (e.g. every reading passage in English)
                if not main[kind] or (n == 1 and 1 in main[kind][-1]):
                    main[kind].append({})
                return main[kind][-1]

            if kind == SINGLE:
                # several columns per line: "1 B  3 D  5 A  7 A"
                for m in re.finditer(r"(?<!\S)(\d{1,4})\s+([ABCDАВС](?:\s*[,/]\s*[ABCDАВС])*)(?=\s|$)", line):
                    letters = [LETTERS[c] for c in re.findall(r"[ABCDАВС]", m.group(2))]
                    slot(int(m.group(1)))[int(m.group(1))] = letters
                continue
            m = re.match(r"^(\d{1,4})\s+(.+)$", line)
            if not m:
                continue
            number, rest = int(m.group(1)), m.group(2).strip()
            last_number[kind] = number
            tokens = rest.split()
            if kind == MATCHING:
                digits = [int(t) for t in tokens if t.isdigit()]
                if len(digits) >= 4:
                    slot(number)[number] = digits[:4]
            elif kind == NUMERIC:
                digits = "".join(t for t in tokens if t.isdigit())
                if digits:
                    slot(number)[number] = digits
        else:
            # "2 D  12 A  21  5 3 2 1": number + letter, or number + a run of digits (matching/open)
            tokens = line.split()
            i = 0
            while i < len(tokens):
                if not tokens[i].isdigit():
                    i += 1
                    continue
                number, j = int(tokens[i]), i + 1
                if j < len(tokens) and tokens[j] in LETTERS:
                    sample.setdefault(number, [tokens[j]])
                    i = j + 1
                    continue
                while j < len(tokens) and tokens[j].isdigit() and not (
                    j + 1 < len(tokens) and tokens[j + 1] in LETTERS
                ):
                    j += 1
                if j > i + 1:
                    sample.setdefault(number, tokens[i + 1:j])
                i = j
    return {"main": main, "sample": sample}


def apply_keys(tasks: list[Task], keys: dict) -> None:
    for t in tasks:
        if t.sample:
            raw = keys["sample"].get(t.number)
            if not raw:
                continue
            if t.kind == SINGLE and raw[0][0] in LETTERS:
                t.answer = [LETTERS[raw[0][0]]]
            elif t.kind == MATCHING:
                digits = [int(x) for x in raw if x.isdigit()]
                t.answer = digits[:4] if len(digits) >= 4 else None
            elif t.kind == NUMERIC:
                t.answer = "".join(x for x in raw if x.isdigit()) or None
            continue
    # Main tasks: a block of tasks gets its key block only if the numbering matches exactly;
    # otherwise the whole block is skipped — better no task than a task with a wrong answer.
    # Blocks of tasks are matched to key blocks in order. Some collections restart the numbering
    # by mistake (the key is continuous), so up to 3 consecutive task blocks may be joined with
    # renumbering — only when the resulting numbers equal the key numbers exactly.
    for kind in (SINGLE, MATCHING, NUMERIC):
        task_blocks: list[list[Task]] = []
        for t in tasks:
            if t.sample or t.kind != kind:
                continue
            if not task_blocks or task_blocks[-1][-1].block != t.block:
                task_blocks.append([])
            task_blocks[-1].append(t)
        pos = 0
        for key in keys["main"].get(kind, []):
            found = None
            for start in range(pos, min(pos + 4, len(task_blocks))):
                merged: list[tuple[int, Task]] = []
                offset = 0
                for size in range(1, 4):
                    if start + size > len(task_blocks):
                        break
                    block = task_blocks[start + size - 1]
                    merged += [(t.number + offset, t) for t in block]
                    offset = max(n for n, _ in merged)
                    numbers = [n for n, _ in merged]
                    if len(set(numbers)) == len(numbers) and set(numbers) == set(key):
                        found = (start, size, merged)
                        break
                if found:
                    break
            if not found:
                print(f"   no tasks for key block of {len(key)} {kind}")
                continue
            start, size, merged = found
            for skipped in task_blocks[pos:start]:
                print(f"   skip {len(skipped)} {kind} tasks without a matching key")
            for n, t in merged:
                t.number = n
                t.answer = key[n]
            pos = start + size
        for skipped in task_blocks[pos:]:
            print(f"   skip {len(skipped)} {kind} tasks without a matching key")


# ---------------------------------------------------------------- images
def render_images(subject: str, pdf_path: Path, tasks: list[Task]) -> None:
    out_dir = STATIC_DIR / subject
    out_dir.mkdir(parents=True, exist_ok=True)
    need = [t for t in tasks if t.image is None and _needs_image(t)]
    if not need:
        return
    with pdfplumber.open(pdf_path) as pdf:
        for t in need:
            last_page = max(ln.page for ln in t.lines)
            end_page, end_top = t.end if t.end else (last_page, None)
            parts = []
            for page_no in range(t.start[0], end_page + 1):
                page = pdf.pages[page_no]
                top = t.start[1] - 6 if page_no == t.start[0] else 45
                if page_no == end_page and end_top is not None:
                    bottom = end_top - 4
                elif page_no == end_page:
                    bottom = max(ln.bottom for ln in t.lines if ln.page == page_no) + 10
                else:
                    bottom = 800
                if bottom - top < 8:
                    continue
                crop = page.crop((40, max(0, top), page.width - 30, min(page.height, bottom)))
                parts.append(_trim(crop.to_image(resolution=130).original.convert("RGB")))
            if not parts:
                continue
            width = max(p.width for p in parts)
            img = Image.new("RGB", (width, sum(p.height for p in parts)), "white")
            y = 0
            for p in parts:
                img.paste(p, (0, y))
                y += p.height
            prefix = "sample" if t.sample else t.kind
            name = f"{prefix}-{t.block}-{t.number}.webp"
            img.save(out_dir / name, "WEBP", quality=72, method=6)
            t.image = f"/static/ntc/{subject}/{name}"


def _trim(img: Image.Image) -> Image.Image:
    """Cut empty white space at the bottom of a crop."""
    gray = img.convert("L").point(lambda v: 0 if v > 235 else 255)
    box = gray.getbbox()
    if not box:
        return img
    return img.crop((0, 0, img.width, min(img.height, box[3] + 12)))


def _needs_image(t: Task) -> bool:
    texts = t.stem + t.options + t.left + ([t.passage] if t.passage else [])
    if t.has_figure or not all(is_clean(x) for x in texts):
        return True
    if t.kind == SINGLE and len(t.options) != 4:
        return True
    if t.kind == MATCHING and (len(t.left) != 4 or len(t.options) != 5):
        return True
    return False


# ---------------------------------------------------------------- output
def to_record(t: Task, lang: str) -> Optional[dict]:
    if t.answer in (None, [], ""):
        return None
    stem = "\n".join(s for s in t.stem if s).strip()
    rec = {
        "subject": t.subject,
        "type": t.kind,
        "topic": t.topic if t.topic and t.topic != "Тестовые задания" else "Общие задания",
        "number": t.number,
        "block": t.block,
        "sample": t.sample,
        "language": lang,
        "passage": t.passage if t.passage and is_clean(t.passage) else None,
        "text": stem if is_clean(stem) else "",
        "image": t.image,
    }
    if t.kind == SINGLE:
        opts = t.options if len(t.options) == 4 and all(is_clean(o) for o in t.options) else ["A", "B", "C", "D"]
        rec["options"] = opts
        rec["correct"] = t.answer if isinstance(t.answer, list) else [t.answer]
    elif t.kind == MATCHING:
        ok = len(t.left) == 4 and len(t.options) == 5 and all(is_clean(x) for x in t.left + t.options)
        rec["left"] = t.left if ok else ["A", "B", "C", "D"]
        rec["options"] = t.options if ok else ["1", "2", "3", "4", "5"]
        rec["correct"] = [d - 1 for d in t.answer]  # 0-based indices into options
        if any(not 0 <= d < 5 for d in rec["correct"]):
            return None
    else:
        rec["options"] = []
        rec["correct"] = str(t.answer)
    if not rec["text"] and not rec["image"]:
        return None
    return rec


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subjects", default=",".join(SUBJECT_FILES))
    parser.add_argument("--no-download", action="store_true")
    args = parser.parse_args()

    bank = json.loads(BANK_PATH.read_text(encoding="utf-8")) if BANK_PATH.exists() else {"questions": []}
    selected = [s.strip() for s in args.subjects.split(",") if s.strip()]
    bank["questions"] = [q for q in bank["questions"] if q["subject"] not in selected]

    for code in selected:
        tasks_file, key_file, lang = SUBJECT_FILES[code]
        print(f"== {code}")
        tasks_pdf = PDF_DIR / tasks_file if args.no_download else download(tasks_file)
        key_pdf = PDF_DIR / key_file.replace("/", "__") if args.no_download else download(key_file)
        tasks = parse_tasks(code, tasks_pdf)
        apply_keys(tasks, parse_keys(key_pdf))
        render_images(code, tasks_pdf, [t for t in tasks if t.answer not in (None, [], "")])
        records = [r for r in (to_record(t, lang) for t in tasks) if r]
        stats = {k: sum(1 for r in records if r["type"] == k and not r["sample"]) for k in (SINGLE, MATCHING, NUMERIC)}
        found = {k: sum(1 for t in tasks if t.kind == k and not t.sample) for k in (SINGLE, MATCHING, NUMERIC)}
        images = sum(1 for r in records if r["image"])
        sample = sum(1 for r in records if r["sample"])
        print(f"   parsed {found}  with keys {stats}  sample {sample}  images {images}")
        bank["questions"].extend(records)

    bank["source"] = SOURCE_PAGE
    bank["generated_at"] = time.strftime("%Y-%m-%d")
    BANK_PATH.write_text(json.dumps(bank, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"Saved {len(bank['questions'])} questions to {BANK_PATH}")


if __name__ == "__main__":
    sys.exit(main())
