from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


class LocalMemory:
    def __init__(self, path: Path | str | None = None):
        self.path = Path(path) if path else Path(":memory:")
        self.connection = sqlite3.connect(str(self.path))
        self.connection.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self) -> None:
        self.connection.execute(
            """
            CREATE TABLE IF NOT EXISTS memory_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kind TEXT NOT NULL,
                text TEXT NOT NULL,
                metadata TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        self.connection.commit()

    def save(self, kind: str, text: str, metadata: dict | None = None) -> dict:
        created_at = datetime.now(timezone.utc).isoformat()
        metadata_json = json.dumps(metadata or {}, sort_keys=True)
        cursor = self.connection.execute(
            "INSERT INTO memory_items(kind, text, metadata, created_at) VALUES (?, ?, ?, ?)",
            (kind, text, metadata_json, created_at),
        )
        self.connection.commit()
        return {"id": cursor.lastrowid, "kind": kind, "text": text, "metadata": metadata or {}, "created_at": created_at}

    def save_note(self, text: str, metadata: dict | None = None) -> dict:
        return self.save("note", text, metadata)

    def save_observation(self, text: str, metadata: dict | None = None) -> dict:
        return self.save("observation", text, metadata)

    def save_command(self, command: str, result: dict) -> dict:
        return self.save("command", command, {"status": result.get("status"), "capability_id": result.get("capability", {}).get("id")})

    def search(self, query: str, limit: int = 10) -> list[dict]:
        like = f"%{query.lower()}%"
        rows = self.connection.execute(
            "SELECT * FROM memory_items WHERE lower(text) LIKE ? OR lower(metadata) LIKE ? ORDER BY id DESC LIMIT ?",
            (like, like, limit),
        ).fetchall()
        return [self._row(row) for row in rows]

    def history(self, limit: int = 10) -> list[dict]:
        rows = self.connection.execute("SELECT * FROM memory_items ORDER BY id DESC LIMIT ?", (limit,)).fetchall()
        return [self._row(row) for row in rows]

    def summary(self) -> dict:
        rows = self.connection.execute("SELECT kind, COUNT(*) as count FROM memory_items GROUP BY kind").fetchall()
        return {"counts": {row["kind"]: row["count"] for row in rows}, "recent": self.history(5)}

    def clear_test_data(self, confirmed: bool = False) -> dict:
        if not confirmed:
            return {"status": "confirmation_required", "message": "Clearing test memory requires confirmation."}
        count = self.connection.execute("SELECT COUNT(*) FROM memory_items").fetchone()[0]
        self.connection.execute("DELETE FROM memory_items")
        self.connection.commit()
        return {"status": "ok", "cleared": count}

    @staticmethod
    def _row(row: sqlite3.Row) -> dict:
        return {
            "id": row["id"],
            "kind": row["kind"],
            "text": row["text"],
            "metadata": json.loads(row["metadata"]),
            "created_at": row["created_at"],
        }
