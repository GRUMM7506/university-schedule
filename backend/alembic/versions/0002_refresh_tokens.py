"""add refresh_tokens table

Revision ID: 0002_refresh_tokens
Revises: 0001_initial_schema
Create Date: 2026-06-28

Note: revision 0001 creates tables via `Base.metadata.create_all`, which
means on a brand-new database it will already create `refresh_tokens` once
the model is added to `app/models/entities.py` (it creates whatever is
currently registered on `Base.metadata`, not just what existed when 0001
was written). This migration exists for databases that already ran 0001
*before* this change and therefore don't have the table yet. We check for
the table's existence first so `alembic upgrade head` is safe either way.
"""

import sqlalchemy as sa
from alembic import op

revision = "0002_refresh_tokens"
down_revision = "0001_initial_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "refresh_tokens" in inspector.get_table_names():
        return

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_refresh_tokens_user_id"),
    )
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "refresh_tokens" not in inspector.get_table_names():
        return
    op.drop_index("ix_refresh_tokens_token_hash", table_name="refresh_tokens")
    op.drop_index("ix_refresh_tokens_user_id", table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
