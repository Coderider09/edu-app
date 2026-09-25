"""remove the NTC task bank: the app uses only its own tasks

Deletes the imported typical tasks of the National Testing Center (source «НЦТ · …»), the
sections they were grouped in and the «Официальный образец ЦВЭ-2026» exam tests.
The app's own tasks, lessons and all user data not tied to these tasks are kept.

Revision ID: 7c1e2f9a4b10
Revises: 4d6e965c66ba
Create Date: 2026-09-25 19:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = '7c1e2f9a4b10'
down_revision = '4d6e965c66ba'
branch_labels = None
depends_on = None

NTC_EXAMS = "SELECT id FROM exam_tests WHERE title LIKE 'Официальный образец ЦВЭ-2026%'"
NTC_QUESTIONS = f"SELECT id FROM questions WHERE source LIKE 'НЦТ%' OR exam_test_id IN ({NTC_EXAMS})"
NTC_SECTIONS = (
    "SELECT id FROM topics WHERE parent_topic_id IS NULL AND \"order\" IN (101, 102, 103) AND title_ru IN "
    "('Задания с выбором ответа', 'Задания на соответствие', 'Задания открытого типа')"
)
IN_USE = (
    "id NOT IN (SELECT topic_id FROM questions WHERE topic_id IS NOT NULL) "
    "AND id NOT IN (SELECT topic_id FROM lessons)"
)


def upgrade() -> None:
    # Dependent rows are deleted explicitly: SQLite does not enforce ON DELETE CASCADE by default
    op.execute(f"DELETE FROM user_answers WHERE question_id IN ({NTC_QUESTIONS})")
    op.execute(f"DELETE FROM marked_questions WHERE question_id IN ({NTC_QUESTIONS})")
    op.execute(f"DELETE FROM test_attempts WHERE test_type = 'exam_test' AND reference_id IN ({NTC_EXAMS})")
    op.execute(f"DELETE FROM questions WHERE id IN ({NTC_QUESTIONS})")
    op.execute(f"DELETE FROM exam_tests WHERE id IN ({NTC_EXAMS})")
    # Topics of the removed sections, then the sections themselves (only if nothing else uses them)
    op.execute(f"DELETE FROM topics WHERE parent_topic_id IN ({NTC_SECTIONS}) AND {IN_USE}")
    op.execute(
        f"DELETE FROM topics WHERE id IN ({NTC_SECTIONS}) AND {IN_USE} "
        "AND id NOT IN (SELECT parent_topic_id FROM topics WHERE parent_topic_id IS NOT NULL)"
    )


def downgrade() -> None:
    # Removed data cannot be restored by a migration; use a database backup if needed
    pass
