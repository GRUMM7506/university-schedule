"""add refresh_token column to users

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-29
"""

import sqlalchemy as sa
from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("users")}
    if "refresh_token" not in cols:
        op.add_column(
            "users",
            sa.Column("refresh_token", sa.String(512), nullable=True),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("users")}
    if "refresh_token" in cols:
        op.drop_column("users", "refresh_token")