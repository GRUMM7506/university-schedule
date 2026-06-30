"""add guest role to user role constraint

Revision ID: 0006
Revises: 0005
Create Date: 2026-06-30
"""

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE users DROP CONSTRAINT IF EXISTS ck_user_role"
    )
    op.execute(
        "ALTER TABLE users ADD CONSTRAINT ck_user_role CHECK (role IN ('Admin', 'Teacher', 'Student', 'Guest'))"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE users DROP CONSTRAINT IF EXISTS ck_user_role"
    )
    op.execute(
        "ALTER TABLE users ADD CONSTRAINT ck_user_role CHECK (role IN ('Admin', 'Teacher', 'Student'))"
    )