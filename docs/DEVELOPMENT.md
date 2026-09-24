# Разработка

## Backend

```bash
cd backend
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements-dev.txt
pytest            # 41 тест на SQLite
ruff check .      # линт
```

### Миграции

После изменения моделей:

```bash
alembic revision --autogenerate -m "описание"
alembic upgrade head
alembic check     # модели и миграции совпадают (выполняется в CI на PostgreSQL)
```

### Контент

- Данные: `python -m app.seed` (идемпотентно) — официальная структура ЦВЭ (`app/seed_ntc.py`), банк заданий НЦТ (`data/ntc_bank.json`), краткая теория, школьное демо. Суперадмин создаётся из `FIRST_SUPERADMIN_EMAIL` / `FIRST_SUPERADMIN_PASSWORD`.
- Контент-менеджера назначает суперадмин: «Пользователи» → поле `admin_role` = `content_manager`.
- Вопросы трёх типов (`question_type`):
  - `single` — `options` (4 варианта), `correct_answer` = `[индекс]` (с нуля);
  - `matching` — `matching_left` (A–D), `options` (1–5), `correct_answer` = индексы вариантов для A..D, например `[2, 0, 4, 1]`;
  - `numeric` — `correct_answer` = `"125"`.

  Для мини-проверки урока заполните `lesson_id`, для фиксированного теста ЦВЭ — `exam_test_id`. Чтобы вопрос попадал в «Пробный ЦВЭ», у него должен быть `subject_id`.
- Субтесты кластеров (A1–A4, максимум баллов, язык для альтернатив) — «Субтесты кластеров» в админке.
- Раздел/четверть — тема без родителя; темы внутри раздела — дочерние (`parent_topic`).

### Обновление банка официальных заданий

Когда НЦТ публикует новые типовые задания:

1. Обновите имена файлов в `SUBJECT_FILES` (`tools/ntc_import.py`).
2. Выполните `pip install -r requirements-dev.txt` и `python -m tools.ntc_import`: скрипт скачает PDF в `data/ntc/pdf/`, разберёт задания, сверит их с ключами и вырежет картинки.
3. Проверьте в выводе строки `skip …`: это блоки, которые не совпали с ключом и были пропущены.
4. Удалите старые задания (или используйте новую БД) и выполните `python -m app.seed`.

### Настройки игровой механики

`app/services/gamification.py`: `BASE_POINTS`, `STREAK_THRESHOLD`, `STREAK_MULTIPLIER`, `COMPLETION_BONUS`, `LEVELS`, `TOPIC_PASS_ACCURACY`, пересчёт в 500 баллов (`scale_subtest`, `estimate_mmt_score`), достижения `ACHIEVEMENTS_SEED`. Максимум баллов по субтестам — в `app/seed_ntc.py` (`CLUSTERS`).

## Mobile

```bash
cd mobile
flutter create --platforms=android,ios --org tj.eduapp .   # один раз
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

- Строки интерфейса: `lib/core/l10n/strings.dart` (ключ → текст для `ru` и `tj`).
- Новый экран: добавьте маршрут в `lib/config/router.dart`; переход оформляется автоматически (`_page`).
- Длительности анимаций задавайте через `motion(ref, ms)`, чтобы они сокращались на слабых устройствах.
