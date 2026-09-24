# data/

- `ntc_bank.json` — official typical tasks of ЦВЭ-2026 with answer keys (National Testing Center, ntc.tj).
- `../app/static/ntc/` — images of tasks with formulas/figures cropped from the official PDFs.

Both are **not stored in git**: redistributing NTC materials requires the Center's permission.
Build them locally (downloads the PDFs from ntc.tj into `data/ntc/pdf/`, ~200 MB, ~20 min):

```bash
cd backend
pip install -r requirements-dev.txt
python -m tools.ntc_import
python -m app.seed
```
