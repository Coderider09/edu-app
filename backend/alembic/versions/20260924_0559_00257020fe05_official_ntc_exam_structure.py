"""official ЦВЭ structure: clusters ↔ subjects (A1–A4), three task types, 500-point scale

Revision ID: 00257020fe05
Revises: 9d0a2638b416
Create Date: 2026-09-24 05:59:32.485089

"""
import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = '00257020fe05'
down_revision = '9d0a2638b416'
branch_labels = None
depends_on = None

question_type = sa.Enum('single', 'matching', 'numeric', name='questiontype', native_enum=False, length=32)


def upgrade() -> None:
    op.create_table(
        'cluster_subjects',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('cluster_id', sa.Integer(), nullable=False),
        sa.Column('subject_id', sa.Integer(), nullable=False),
        sa.Column('position', sa.Integer(), nullable=False),
        sa.Column('max_score', sa.Integer(), nullable=False),
        sa.Column('language_track', sa.String(length=4), nullable=True),
        sa.ForeignKeyConstraint(['cluster_id'], ['clusters.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['subject_id'], ['subjects.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('cluster_id', 'subject_id', name='uq_cluster_subject'),
    )
    op.create_index('ix_cluster_subjects_cluster_id', 'cluster_subjects', ['cluster_id'])
    op.create_index('ix_cluster_subjects_subject_id', 'cluster_subjects', ['subject_id'])

    # Keep existing cluster ↔ subject links
    op.execute(
        'INSERT INTO cluster_subjects (cluster_id, subject_id, position, max_score) '
        'SELECT cluster_id, id, "order", 125 FROM subjects WHERE cluster_id IS NOT NULL'
    )

    with op.batch_alter_table('clusters') as batch_op:
        batch_op.add_column(sa.Column('duration_minutes', sa.Integer(), nullable=False, server_default='200'))

    with op.batch_alter_table('questions') as batch_op:
        batch_op.add_column(sa.Column('question_type', question_type, nullable=False, server_default='single'))
        batch_op.add_column(sa.Column('passage', sa.Text(), nullable=True))
        batch_op.add_column(sa.Column('matching_left', sa.JSON(), nullable=True))
        batch_op.add_column(sa.Column('correct_answer', sa.JSON(), nullable=True))
        batch_op.add_column(sa.Column('source', sa.String(length=200), nullable=True))
        batch_op.alter_column('correct_option_index', existing_type=sa.Integer(), nullable=True)

    with op.batch_alter_table('subjects') as batch_op:
        batch_op.add_column(sa.Column('code', sa.String(length=32), nullable=True))
        batch_op.add_column(sa.Column('exam_structure', sa.JSON(), nullable=True))
        batch_op.create_unique_constraint('uq_subjects_code', ['code'])
        batch_op.drop_index('ix_subjects_cluster_id')
        # the foreign key on cluster_id is dropped together with the column
        batch_op.drop_column('cluster_id')

    with op.batch_alter_table('test_attempts') as batch_op:
        batch_op.add_column(sa.Column('points', sa.Integer(), nullable=False, server_default='0'))
        batch_op.add_column(sa.Column('max_points', sa.Integer(), nullable=False, server_default='0'))
        batch_op.add_column(sa.Column('details', sa.JSON(), nullable=True))

    with op.batch_alter_table('user_answers') as batch_op:
        batch_op.add_column(sa.Column('answer', sa.JSON(), nullable=True))
        batch_op.add_column(sa.Column('points', sa.Integer(), nullable=False, server_default='0'))
        batch_op.alter_column('selected_option_index', existing_type=sa.Integer(), nullable=True)

    # Old estimates were on the 100–200 scale; the ЦВЭ scale is 0–500
    op.execute('UPDATE test_attempts SET mmt_score = NULL')
    op.execute('UPDATE user_answers SET points = 1 WHERE is_correct')
    op.execute(
        'UPDATE test_attempts SET points = correct_count, max_points = total_count WHERE max_points = 0'
    )


def downgrade() -> None:
    with op.batch_alter_table('user_answers') as batch_op:
        batch_op.alter_column('selected_option_index', existing_type=sa.Integer(), nullable=False)
        batch_op.drop_column('points')
        batch_op.drop_column('answer')

    with op.batch_alter_table('test_attempts') as batch_op:
        batch_op.drop_column('details')
        batch_op.drop_column('max_points')
        batch_op.drop_column('points')

    with op.batch_alter_table('subjects') as batch_op:
        batch_op.add_column(sa.Column('cluster_id', sa.Integer(), nullable=True))
        batch_op.create_foreign_key('fk_subjects_cluster_id', 'clusters', ['cluster_id'], ['id'])
        batch_op.create_index('ix_subjects_cluster_id', ['cluster_id'])
        batch_op.drop_constraint('uq_subjects_code', type_='unique')
        batch_op.drop_column('exam_structure')
        batch_op.drop_column('code')

    with op.batch_alter_table('questions') as batch_op:
        batch_op.alter_column('correct_option_index', existing_type=sa.Integer(), nullable=False)
        batch_op.drop_column('source')
        batch_op.drop_column('correct_answer')
        batch_op.drop_column('matching_left')
        batch_op.drop_column('passage')
        batch_op.drop_column('question_type')

    with op.batch_alter_table('clusters') as batch_op:
        batch_op.drop_column('duration_minutes')

    op.drop_index('ix_cluster_subjects_subject_id', table_name='cluster_subjects')
    op.drop_index('ix_cluster_subjects_cluster_id', table_name='cluster_subjects')
    op.drop_table('cluster_subjects')
