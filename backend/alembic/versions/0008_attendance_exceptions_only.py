"""attendance stores exceptions only (absent/late), not presence

Migration 0007 collapsed the old 3-state attendance scale (absent/late/
present) down to a binary absent/present, keeping a row for every student
on every marked lesson. This migration changes the model again: presence
is no longer stored at all — only exceptions (0=absent, 1=late) get a row,
and a student with no row for a given lesson is presumed present.

Consequence for existing data: under 0007, mark=1 meant "present" — but
under this new scheme mark=1 means "late", which is a different and
incompatible fact we don't have (0007 already discarded the true
late/present distinction). The safe choice is to delete those rows rather
than mislabel real presences as "late" — so any student who isn't recorded
as absent goes back to the (correct) default of "present", and no lateness
information is fabricated. mark=0 (absent) is unaffected — it meant
"absent" before and still does.

Revision ID: 0008
Revises: 0007
Create Date: 2026-07-02
"""

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rows that meant "present" under 0007's binary scheme would otherwise
    # be silently reinterpreted as "late" — remove them instead.
    op.execute("DELETE FROM attendance WHERE mark = 1")


def downgrade() -> None:
    # Not reversible: we can't recover which of the now-absent rows used to
    # exist as "present" records. No-op.
    pass
