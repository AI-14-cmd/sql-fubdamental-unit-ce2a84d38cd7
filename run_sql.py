import os
import re
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "scheduler.sql")
LABEL = re.compile(r"--\s*REPORT:\s*(.+)")


def split_statements(sql_text):
    """Cut the script into single statements, keeping their comments."""
    statements = []
    buffer = ""
    for line in sql_text.splitlines(keepends=True):
        buffer += line
        if sqlite3.complete_statement(buffer):
            statements.append(buffer.strip())
            buffer = ""
    return statements


def run_script(conn, path=SCRIPT):
    """Run every statement; return the ones that produced rows."""
    with open(path, encoding="utf-8-sig") as f:
        sql_text = f.read()
    reports = []
    for statement in split_statements(sql_text):
        cursor = conn.execute(statement)
        if cursor.description is None:
            continue
        match = LABEL.search(statement)
        reports.append({
            "label": match.group(1).strip() if match else "Result",
            "sql": statement,
            "columns": [c[0] for c in cursor.description],
            "rows": cursor.fetchall(),
        })
    conn.commit()
    return reports


def print_report(report):
    columns = report["columns"]
    rows = [["NULL" if v is None else str(v) for v in row]
            for row in report["rows"]]
    widths = [max([len(c)] + [len(r[i]) for r in rows])
              for i, c in enumerate(columns)]
    print("== " + report["label"] + " ==")
    print("  ".join(c.ljust(w) for c, w in zip(columns, widths)).rstrip())
    for row in rows:
        print("  ".join(v.ljust(w) for v, w in zip(row, widths)).rstrip())
    if not rows:
        print("(no rows)")
    print()


def main():
    conn = sqlite3.connect(":memory:")
    for report in run_script(conn):
        print_report(report)
    conn.close()


if __name__ == "__main__":
    main()