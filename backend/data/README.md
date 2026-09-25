# data/

All task content here is written by the EduApp team:

- `own/<subject>_<language>.json` — own tasks in the ЦВЭ format with solutions, built from
  `tools/own_bank/*.py` by `python -m tools.own_bank.build`;
- `lessons/<subject>_<language>.json` — lessons with mini-checks and exercises, built from
  `tools/lessons/*.py` by `python -m tools.lessons.build`.

`python -m app.seed` loads both into the database (idempotent).
