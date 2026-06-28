"""add user_id column to teachers and students tables

Revision ID: 0003_add_user_id_to_teachers_and_students
Revises: 0002_refresh_tokens
Create Date: 2026-06-28
"""

import sqlalchemy as sa
from alembic import op

revision = "0003"
down_revision = "0002_refresh_tokens"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # --- teachers ---
    cols_teachers = {c["name"] for c in inspector.get_columns("teachers")}
    if "user_id" not in cols_teachers:
        op.add_column(
            "teachers",
            sa.Column("user_id", sa.Integer(), nullable=True),
        )
        op.create_index("ix_teachers_user_id", "teachers", ["user_id"])
        op.create_foreign_key(
            "fk_teachers_user_id",
            "teachers",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )

    # --- students ---
    cols_students = {c["name"] for c in inspector.get_columns("students")}
    if "user_id" not in cols_students:
        op.add_column(
            "students",
            sa.Column("user_id", sa.Integer(), nullable=True),
        )
        op.create_index("ix_students_user_id", "students", ["user_id"])
        op.create_foreign_key(
            "fk_students_user_id",
            "students",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    cols_teachers = {c["name"] for c in inspector.get_columns("teachers")}
    if "user_id" in cols_teachers:
        op.drop_constraint("fk_teachers_user_id", "teachers", type_="foreignkey")
        op.drop_index("ix_teachers_user_id", table_name="teachers")
        op.drop_column("teachers", "user_id")

    cols_students = {c["name"] for c in inspector.get_columns("students")}
    if "user_id" in cols_students:
        op.drop_constraint("fk_students_user_id", "students", type_="foreignkey")
        op.drop_index("ix_students_user_id", table_name="students")
        op.drop_column("students", "user_id")

