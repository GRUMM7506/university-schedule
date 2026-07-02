"""discipline load semester, binary attendance, performance mark range

Adds discipline_loads.semester (backfilled from the parent subject),
collapses Attendance.mark down to a binary absent/present scale (old
"late"=1 and "present"=2 both become present=1), and adds a DB-level
check that ties Performance.mark's valid range to control_type.

Revision ID: 0007
Revises: 0006
Create Date: 2026-07-01
"""

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── discipline_loads.semester ───────────────────────────────────────────
    op.execute("ALTER TABLE discipline_loads ADD COLUMN IF NOT EXISTS semester INTEGER")
    op.execute(
        """
        UPDATE discipline_loads dl
        SET semester = s.semester
        FROM subjects s
        WHERE dl.subject_id = s.id AND dl.semester IS NULL
        """
    )
    # Anything left without a match (shouldn't normally happen) falls back to 1
    op.execute("UPDATE discipline_loads SET semester = 1 WHERE semester IS NULL")
    op.execute("ALTER TABLE discipline_loads ALTER COLUMN semester SET NOT NULL")
    op.execute(
        "ALTER TABLE discipline_loads DROP CONSTRAINT IF EXISTS ck_discipline_load_semester"
    )
    op.execute(
        "ALTER TABLE discipline_loads ADD CONSTRAINT ck_discipline_load_semester CHECK (semester BETWEEN 1 AND 12)"
    )

    # ── attendance.mark → binary ────────────────────────────────────────────
    # Old scale: 0=absent, 1=late, 2=present. New scale: 0=absent, 1=present.
    # A "late" mark still means the student showed up, so it collapses to present.
    op.execute("UPDATE attendance SET mark = CASE WHEN mark = 0 THEN 0 ELSE 1 END")
    op.execute("ALTER TABLE attendance DROP CONSTRAINT IF EXISTS ck_attendance_mark_binary")
    op.execute("ALTER TABLE attendance ADD CONSTRAINT ck_attendance_mark_binary CHECK (mark IN (0, 1))")

    # ── performance.mark range tied to control_type ─────────────────────────
    op.execute("ALTER TABLE performance DROP CONSTRAINT IF EXISTS ck_performance_mark_range")
    op.execute(
        """
        ALTER TABLE performance ADD CONSTRAINT ck_performance_mark_range
        CHECK ((control_type = 0 AND mark BETWEEN 0 AND 3) OR (control_type = 1 AND mark BETWEEN 0 AND 5))
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE performance DROP CONSTRAINT IF EXISTS ck_performance_mark_range")
    op.execute("ALTER TABLE attendance DROP CONSTRAINT IF EXISTS ck_attendance_mark_binary")
    op.execute("ALTER TABLE discipline_loads DROP CONSTRAINT IF EXISTS ck_discipline_load_semester")
    op.execute("ALTER TABLE discipline_loads DROP COLUMN IF EXISTS semester")
