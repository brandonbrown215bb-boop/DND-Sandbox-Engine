"""Local web server and CLI entry point for Rook's Grimoire Content Workbench.

Usage:
  python tools/content_editor/app.py serve --port 8765
  python tools/content_editor/app.py seed-demo
  python tools/content_editor/app.py export --pack ember_pack --mode both
"""

from __future__ import annotations

import argparse
import json
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

EDITOR_ROOT = Path(__file__).resolve().parent
if str(EDITOR_ROOT) not in sys.path:
    sys.path.insert(0, str(EDITOR_ROOT))

from engine import (  # noqa: E402
    DEFAULT_EXPORTS_DIR,
    DEFAULT_WORKSPACES_DIR,
    TEMPLATES,
    CatalogIndex,
    PackWorkspace,
    convert_spell_to_shared,
    diff_records,
    evaluate_record_support,
    prepare_game_pack_record,
    slugify_id,
)

UI_DIR = EDITOR_ROOT / "ui"


class EditorContext:
    def __init__(self) -> None:
        self.catalog = CatalogIndex()
        self.workspaces: dict[str, PackWorkspace] = {}
        self.catalog_counts = self._compute_catalog_counts()

    def _compute_catalog_counts(self) -> dict[str, dict[str, int]]:
        counts: dict[str, dict[str, int]] = {}
        for ctype, bucket in self.catalog.records_by_type.items():
            c_map = {
                "total": len(bucket),
                "shared-ready": 0,
                "native-id-bound": 0,
                "draft-unsupported": 0,
                "staged-reference": 0,
            }
            for entry in bucket.values():
                st = evaluate_record_support(ctype, entry["active_record"], self.catalog.contract)[
                    "status"
                ]
                c_map[st] = c_map.get(st, 0) + 1
            counts[ctype] = c_map
        return counts

    def get_workspace(self, pack_id: str) -> PackWorkspace:
        norm = slugify_id(pack_id or "ember_pack")
        if norm not in self.workspaces:
            self.workspaces[norm] = PackWorkspace(norm, catalog=self.catalog)
        return self.workspaces[norm]

    def list_workspace_ids(self) -> list[str]:
        DEFAULT_WORKSPACES_DIR.mkdir(parents=True, exist_ok=True)
        found = [
            p.name
            for p in sorted(DEFAULT_WORKSPACES_DIR.iterdir())
            if p.is_dir() and (p / "workspace.json").exists()
        ]
        if "ember_pack" not in found:
            self.get_workspace("ember_pack")
            found.append("ember_pack")
        return sorted(set(found))


def make_handler(ctx: EditorContext):
    class WorkbenchHandler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
            return

        def _send_json(self, payload: Any, status: int = HTTPStatus.OK) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _send_static(self, file_path: Path, content_type: str) -> None:
            if not file_path.exists():
                self.send_error(HTTPStatus.NOT_FOUND, f"Missing static file: {file_path.name}")
                return
            body = file_path.read_bytes()
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _read_body_json(self) -> dict[str, Any]:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
            return json.loads(raw or "{}")

        def do_GET(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            path = parsed.path
            qs = parse_qs(parsed.query)

            if path in ("/", "/index.html"):
                self._send_static(UI_DIR / "index.html", "text/html; charset=utf-8")
                return
            if path == "/ui/styles.css":
                self._send_static(UI_DIR / "styles.css", "text/css; charset=utf-8")
                return
            if path == "/ui/workbench.js":
                self._send_static(UI_DIR / "workbench.js", "application/javascript; charset=utf-8")
                return

            if path == "/api/state":
                pack_id = qs.get("pack", ["ember_pack"])[0]
                ws = ctx.get_workspace(pack_id)
                self._send_json(
                    {
                        "contract": ctx.catalog.contract,
                        "templates": TEMPLATES,
                        "pack_id": ws.pack_id,
                        "metadata": ws.get_metadata(),
                        "drafts": ws.list_drafts(),
                        "available_packs": ctx.list_workspace_ids(),
                        "pack_manifest_preview": ws.preview_pack_manifest(),
                        "catalog_counts": ctx.catalog_counts,
                    }
                )
                return

            if path == "/api/catalog":
                ctype = qs.get("type", ["spell"])[0]
                search = qs.get("search", [""])[0]
                status_filter = qs.get("status", [""])[0]
                items = ctx.catalog.list_entries(ctype, search=search, status_filter=status_filter)
                self._send_json({"items": items})
                return

            if path == "/api/entry":
                pack_id = qs.get("pack", ["ember_pack"])[0]
                ctype = qs.get("type", ["spell"])[0]
                record_id = qs.get("id", [""])[0]
                ws = ctx.get_workspace(pack_id)
                cat_entry = ctx.catalog.get_entry(ctype, record_id)
                draft = ws.get_draft(ctype, record_id) if ctype in ("spell", "item") else None
                active_rec = (
                    draft["record"]
                    if draft is not None
                    else (cat_entry["active_record"] if cat_entry else None)
                )
                diag = (
                    draft["diagnostics"]
                    if draft is not None
                    else (
                        evaluate_record_support(ctype, active_rec, ctx.catalog.contract)
                        if active_rec is not None
                        else None
                    )
                )
                candidate_preview = (
                    prepare_game_pack_record(ctype, active_rec, ctx.catalog.contract)
                    if active_rec is not None and ctype in ("spell", "item")
                    else active_rec
                )
                field_diff = diff_records(
                    cat_entry["winner_record"] if cat_entry else None,
                    cat_entry["replaced_sources"] if cat_entry else [],
                    cat_entry["active_record"] if cat_entry else None,
                    draft["record"] if draft is not None else active_rec,
                )
                class_comparison = (
                    ctx.catalog.build_class_comparison(record_id, workspace=ws)
                    if ctype == "class"
                    else None
                )
                self._send_json(
                    {
                        "catalog_entry": cat_entry,
                        "draft": draft,
                        "diagnostics": diag,
                        "candidate_preview": candidate_preview,
                        "field_diff": field_diff,
                        "class_comparison": class_comparison,
                    }
                )
                return

            self.send_error(HTTPStatus.NOT_FOUND, f"Unknown endpoint {path}")

        def do_POST(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            path = parsed.path
            try:
                body = self._read_body_json()
                pack_id = str(body.get("pack_id", "ember_pack"))
                ws = ctx.get_workspace(pack_id)

                if path == "/api/validate_live":
                    ctype = str(body.get("content_type", "spell"))
                    record = body.get("record", {})
                    is_clone = bool(body.get("is_cloned_homebrew", False)) or ":" in str(
                        record.get("id", "")
                    )
                    diag = evaluate_record_support(
                        ctype, record, ctx.catalog.contract, is_cloned_homebrew=is_clone
                    )
                    candidate = (
                        prepare_game_pack_record(ctype, record, ctx.catalog.contract)
                        if ctype in ("spell", "item")
                        else record
                    )
                    cat_entry = ctx.catalog.get_entry(ctype, str(record.get("id", "")))
                    fdiff = diff_records(
                        cat_entry["winner_record"] if cat_entry else None,
                        cat_entry["replaced_sources"] if cat_entry else [],
                        cat_entry["active_record"] if cat_entry else None,
                        record,
                    )
                    self._send_json(
                        {
                            "diagnostics": diag,
                            "candidate_preview": candidate,
                            "field_diff": fdiff,
                        }
                    )
                    return

                if path == "/api/stage_override":
                    ctype = str(body["content_type"])
                    source_id = str(body["source_id"])
                    draft = ws.stage_override(ctype, source_id)
                    self._send_json({"draft": draft})
                    return

                if path == "/api/clone_homebrew":
                    ctype = str(body["content_type"])
                    source_id = str(body["source_id"])
                    new_slug = str(body.get("new_slug", source_id))
                    new_name = str(body.get("new_name", ""))
                    auto_conv = bool(body.get("auto_convert_shared", False))
                    draft = ws.clone_as_homebrew(ctype, source_id, new_slug, new_name or None)
                    if ctype == "spell" and auto_conv:
                        converted = convert_spell_to_shared(draft["record"], ws.contract)
                        draft = ws.save_draft("spell", converted, origin=draft["origin"])
                    self._send_json({"draft": draft})
                    return

                if path == "/api/create_template":
                    template_id = str(body["template_id"])
                    new_slug = str(body.get("new_slug", "custom_entry"))
                    new_name = str(body.get("new_name", "New Homebrew"))
                    draft = ws.create_from_template(template_id, new_slug, new_name)
                    self._send_json({"draft": draft})
                    return

                if path == "/api/delete_draft":
                    ctype = str(body["content_type"])
                    record_id = str(body["record_id"])
                    removed = ws.delete_draft(ctype, record_id)
                    self._send_json({"removed": removed})
                    return

                if path == "/api/update_draft":
                    ctype = str(body["content_type"])
                    record_id = str(body["record_id"])
                    incoming_record = body.get("record")
                    patch = body.get("patch")

                    if incoming_record is not None and (
                        not isinstance(incoming_record, dict) or incoming_record.get("id") != record_id
                    ):
                        raise ValueError("Draft record ID must match the selected record ID.")

                    existing = ws.get_draft(ctype, record_id)
                    if existing is None and incoming_record is not None:
                        # Automatically stage override if saving edits to a catalog record
                        cat_entry = ctx.catalog.get_entry(ctype, record_id)
                        origin = (
                            {
                                "mode": "override",
                                "source_id": record_id,
                                "winner_coord": cat_entry["winner_coord"],
                                "replaces": [cat_entry["winner_coord"]]
                                + [r["coord"] for r in cat_entry["replaced_sources"]],
                            }
                            if cat_entry is not None
                            else {"mode": "homebrew_new", "replaces": []}
                        )
                        locked = dict(incoming_record)
                        locked["id"] = record_id
                        draft = ws.save_draft(ctype, locked, origin=origin)
                    elif incoming_record is not None and existing is not None:
                        locked = dict(incoming_record)
                        locked["id"] = record_id
                        draft = ws.save_draft(ctype, locked, origin=existing["origin"])
                    else:
                        draft = ws.update_draft(ctype, record_id, patch or {})
                    self._send_json({"draft": draft})
                    return

                if path == "/api/convert_shared":
                    record_in = body.get("record")
                    record_id = str(body.get("record_id") or (record_in or {}).get("id", ""))
                    save_to_ws = bool(body.get("save_to_workspace", True))
                    if record_in is not None:
                        converted = convert_spell_to_shared(record_in, ws.contract)
                    else:
                        current = ws.get_draft("spell", record_id)
                        if current is None:
                            current = ws.stage_override("spell", record_id)
                        converted = convert_spell_to_shared(current["record"], ws.contract)

                    if save_to_ws and record_id:
                        existing = ws.get_draft("spell", record_id)
                        origin = existing["origin"] if existing else None
                        draft = ws.save_draft("spell", converted, origin=origin)
                        self._send_json({"draft": draft, "record": converted})
                    else:
                        diag = evaluate_record_support("spell", converted, ws.contract)
                        self._send_json({"record": converted, "diagnostics": diag})
                    return

                if path == "/api/update_pack_meta":
                    meta = ws.update_metadata(body)
                    self._send_json({"pack_id": ws.pack_id, "metadata": meta})
                    return

                if path == "/api/export":
                    mode = str(body.get("mode", "both"))
                    revision = str(body.get("revision", "r1"))
                    modes = (
                        ["game_pack_candidate", "draft_lossless"]
                        if mode == "both"
                        else [mode]
                    )
                    results = [ws.export_pack(mode=m, revision=revision) for m in modes]
                    self._send_json({"exports": results})
                    return

                self.send_error(HTTPStatus.NOT_FOUND, f"Unknown POST endpoint {path}")
            except Exception as exc:
                self._send_json({"error": str(exc)}, status=HTTPStatus.BAD_REQUEST)

    return WorkbenchHandler


def seed_demo_pack() -> dict[str, Any]:
    """Seeds `ember_pack` with realistic overrides, converted clones, ordered steps, and carrier items."""
    ctx = EditorContext()
    ws = ctx.get_workspace("ember_pack")
    ws.update_metadata(
        {
            "name": "Ember & Arcane Pack",
            "author": "Rook",
            "version": "0.2.0",
        }
    )

    # 1. Override an existing catalog spell (`magic_missile`) while preserving its dedicated fields
    ws.stage_override("spell", "magic_missile")
    ws.update_draft(
        "spell",
        "magic_missile",
        {
            "description": "Three glowing darts of magical force strike their targets automatically (Ember Pack balance pass).",
        },
    )

    # 2. Clone `fire_bolt` into `ember_pack:cinder_bolt` and convert it to `execution: "shared"`
    cloned = ws.clone_as_homebrew("spell", "fire_bolt", "cinder_bolt", "Cinder Bolt")
    shared_cinder = convert_spell_to_shared(cloned["record"], ws.contract)
    shared_cinder["classes"] = ["wizard", "sorcerer"]
    shared_cinder["upcast"] = {"damage_per_level": "1d10"}
    ws.save_draft("spell", shared_cinder, origin=cloned["origin"])

    # 3. Create an ADR-0019 Ordered Steps spell (`ember_pack:frost_shard`)
    ws.create_from_template("spell_ordered_steps", "frost_shard", "Frost Shard")

    # 4. Create a Batch L source-benefit carrier ring (`ember_pack:ember_signet_ring`)
    ws.save_draft(
        "item",
        {
            "id": "ember_pack:ember_signet_ring",
            "name": "Ember Signet Ring",
            "type": "ring",
            "rarity": "uncommon",
            "value": 250,
            "weight": 0.1,
            "description": "Warm iron ring etched with a phoenix crest. Grants +1 AC and +5 ft walking speed while worn.",
            "source_benefits": [
                {"stat": "AC", "amount": 1},
                {"stat": "speed", "amount": 1},
            ],
            "starting_equipment_classes": ["wizard", "fighter"],
        },
        origin={"mode": "homebrew_new", "replaces": []},
    )

    # 5. Create a Batch 021 spell-permission wand (`ember_pack:wand_of_cinders`)
    ws.create_from_template("item_spell_wand", "wand_of_cinders", "Wand of Cinders")

    cand_export = ws.export_pack(mode="game_pack_candidate", revision="r1")
    lossless_export = ws.export_pack(mode="draft_lossless", revision="r1")
    return {
        "workspace_dir": str(ws.root),
        "game_pack_candidate": cand_export,
        "draft_lossless": lossless_export,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Rook's Grimoire Content Workbench (VS-83)")
    sub = parser.add_subparsers(dest="command")

    serve_p = sub.add_parser("serve", help="Run the local Grimoire Content Workbench web UI")
    serve_p.add_argument("--host", default="127.0.0.1")
    serve_p.add_argument("--port", type=int, default=8765)

    sub.add_parser("seed-demo", help="Seed the demo workspace 'ember_pack' and export both modes")

    exp_p = sub.add_parser("export", help="Export an existing workspace pack")
    exp_p.add_argument("--pack", default="ember_pack")
    exp_p.add_argument(
        "--mode",
        choices=["game_pack_candidate", "draft_lossless", "both"],
        default="both",
    )
    exp_p.add_argument("--revision", default="r1")

    args = parser.parse_args(argv)
    cmd = args.command or "serve"

    if cmd == "seed-demo":
        summary = seed_demo_pack()
        print(
            json.dumps(
                {
                    "workspace": summary["workspace_dir"],
                    "candidate_export": summary["game_pack_candidate"]["export_dir"],
                    "lossless_export": summary["draft_lossless"]["export_dir"],
                },
                indent=2,
            )
        )
        return 0

    if cmd == "export":
        ctx = EditorContext()
        ws = ctx.get_workspace(args.pack)
        modes = (
            ["game_pack_candidate", "draft_lossless"]
            if args.mode == "both"
            else [args.mode]
        )
        out = [
            ws.export_pack(mode=m, output_root=DEFAULT_EXPORTS_DIR, revision=args.revision)
            for m in modes
        ]
        print(json.dumps(out, indent=2))
        return 0

    ctx = EditorContext()
    server = ThreadingHTTPServer((args.host, args.port), make_handler(ctx))
    print(f"Grimoire Content Workbench running at http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
