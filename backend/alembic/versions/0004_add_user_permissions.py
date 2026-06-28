"""add user_permissions table

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-28
"""

import sqlalchemy as sa
from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "user_permissions" in inspector.get_table_names():
        return

    op.create_table(
        "user_permissions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False, index=True),
        sa.Column("permission", sa.String(80), nullable=False),
        sa.Column("is_granted", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.UniqueConstraint("user_id", "permission", name="uq_user_permission"),
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "user_permissions" not in inspector.get_table_names():
        return
    op.drop_table("user_permissions")
