import os
import re

from sqlalchemy import text

from app.core.security import get_password_hash
from app.db.session import SessionLocal
from app.models import User
from app.db.base import Base


def reset(db):
    engine = db.get_bind()
    with engine.connect() as conn:
        conn.execute(text("DROP SCHEMA public CASCADE; CREATE SCHEMA public;"))
        conn.commit()


def _convert_copy_to_insert(sql_text: str) -> str:
    extra_columns = {
        "teachers": {"user_id"},
        "students": {"user_id"},
    }
    missing_columns = {
        "users": {"refresh_token"},
    }

    pattern = re.compile(
        r"COPY\s+public\.(\w+)\s*\(([^)]+)\)\s+FROM\s+stdin;\n(.*?)\n\\\.\n",
        re.DOTALL,
    )

    def replacer(match: re.Match) -> str:
        table = match.group(1)
        columns = [col.strip() for col in match.group(2).split(",")]
        rows_raw = []
        for line in match.group(3).splitlines():
            line = line.strip()
            if not line or line.startswith("\\."):
                continue
            rows_raw.append(line.split("\t"))

        if not rows_raw:
            return "-- no rows"

        filtered_cols = []
        skip_indices = set()
        for i, col in enumerate(columns):
            if table in extra_columns and col in extra_columns[table]:
                skip_indices.add(i)
            else:
                filtered_cols.append(col)

        if table in missing_columns:
            for col in missing_columns[table]:
                filtered_cols.append(col)

        rows = []
        for parts in rows_raw:
            values = []
            for i, part in enumerate(parts):
                if i in skip_indices:
                    continue
                part = part.strip()
                if part == r"\N" or part == r"\\N":
                    values.append("NULL")
                else:
                    if re.match(r"^-?\d+$", part):
                        values.append(part)
                    else:
                        s = part.replace("'", "''")
                        values.append(f"'{s}'")
            for _ in missing_columns.get(table, []):
                values.append("NULL")
            rows.append(f"({', '.join(values)})")

        columns_sql = ", ".join(filtered_cols)
        values_sql = ",\n".join(rows)
        return f"INSERT INTO public.{table} ({columns_sql}) VALUES\n{values_sql};"

    return pattern.sub(replacer, sql_text)


def main() -> None:
    db = SessionLocal()
    try:
        reset(db)

        dump_path = os.path.join(os.path.dirname(__file__), "..", "dbb_plain.sql")
        if not os.path.exists(dump_path):
            raise FileNotFoundError(f"'{dump_path}' not found")

        with open(dump_path, "r", encoding="utf-8") as f:
            sql = f.read()

        sql = _convert_copy_to_insert(sql)

        keep_patterns = [
            r"^SELECT pg_catalog\.setval",
            r"^INSERT INTO",
            r"^ALTER TABLE ONLY public\..*ADD CONSTRAINT",
            r"^CREATE UNIQUE INDEX",
            r"^CREATE INDEX",
            r"^ALTER TABLE ONLY public\..*ALTER COLUMN id SET DEFAULT",
        ]
        lines = []
        for line in sql.splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            if any(re.match(p, stripped) for p in keep_patterns):
                lines.append(stripped)

        filtered_sql = "\n".join(lines) + ";"

        statements = [s.strip() for s in filtered_sql.split(";") if s.strip()]
        with db.connection() as conn:
            for stmt in statements:
                conn.execute(text(stmt))
            conn.commit()

        print("Seed completed from dbb.sql.")
    finally:
        db.close()


if __name__ == "__main__":
    main()