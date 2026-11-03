"""Create fresh chats in the running Ziva editor through its local panel API.

This is Ziva's private v3.3.3 API, not its public Godot MCP interface.
No dependencies, database writes, UI automation, or automatic send retries.
"""

import argparse
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


PROJECT = Path(__file__).resolve().parents[1]


class Ziva:
    def __init__(self, url):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost", "::1"):
            raise ValueError("Use the running editor's local HTTP URL.")
        self.url = url.rstrip("/")

    def call(self, method, payload=None):
        request = urllib.request.Request(
            f"{self.url}/api/rpc/{method}",
            json.dumps({"json": payload} if payload is not None else {}).encode(),
            {"Content-Type": "application/json", "Origin": self.url},
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                envelope = json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"Ziva {method}: HTTP {error.code}: {error.read(2000).decode(errors='replace')}") from error
        return envelope.get("json", envelope)

    def bootstrap(self):
        result = self.call("plugin/bootstrap")
        bridge = result.get("bridge", {})
        if not bridge.get("connected"):
            raise RuntimeError("Ziva is not connected to its Godot editor.")
        actual = Path(bridge.get("projectPath", "")).resolve()
        if actual != PROJECT:
            raise RuntimeError(f"Wrong editor: {actual}; expected {PROJECT}")
        return result


def emit(value):
    print(json.dumps(value, ensure_ascii=True, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:7012")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="List chats and their states without loading transcripts.")
    create = commands.add_parser("new", help="Send the first prompt in a NEW conversation.")
    prompt = create.add_mutually_exclusive_group(required=True)
    prompt.add_argument("--prompt")
    prompt.add_argument("--prompt-file", type=Path)
    create.add_argument("--model", default="ext:chatgpt:gpt-6-luna",
                        help="Exact model route; default preserves the owner's current Codex Luna route.")
    create.add_argument("--effort", choices=["low", "medium", "high", "xhigh", "max"], default="high")
    create.add_argument("--mode", choices=["ask", "default", "plan"], default="default")
    create.add_argument("--title")
    status = commands.add_parser("status", help="Read one chat's latest message snapshot.")
    status.add_argument("chat_id")
    args = parser.parse_args()
    client = Ziva(args.url)
    boot = client.bootstrap()
    chats = boot.get("sidebar", {}).get("chats", [])
    if args.command == "list":
        emit([{key: chat.get(key) for key in ("id", "title", "modelSelection", "status")}
              for chat in chats])
    elif args.command == "status":
        emit(client.call("chats/snapshot", {"chatId": args.chat_id}))
    else:
        text = args.prompt_file.read_text(encoding="utf-8-sig") if args.prompt_file else args.prompt
        if not text.strip():
            raise ValueError("The first prompt cannot be empty.")
        models = [model for provider in boot.get("providers", []) for model in provider.get("models", [])]
        routes = {model["slug"] for model in models}
        routes.update(route["modelId"] for model in models for route in model.get("byoRoutes", []))
        if args.model not in routes:
            raise ValueError(f"Model route is not advertised by this editor: {args.model}")
        now = int(time.time() * 1000)
        # Deliberately omit chatId, parent/fork IDs, history and resume cursors.
        payload = {
            "modelSelection": {"provider": "zivacode", "modelId": args.model,
                               "serviceTier": "standard", "reasoningEffort": args.effort},
            "interactionMode": args.mode,
            "parts": [{"type": "text", "text": text,
                       "time": {"started": now, "completed": now}}],
        }
        try:
            result = client.call("chats/sendPrompt", payload)
        except Exception:
            print("Send failed or its outcome is unknown. Do not resend blindly; run list first.", file=sys.stderr)
            raise
        chat = result["chat"]
        chat_id = chat["id"]
        if any(old["id"] == chat_id for old in chats):
            raise RuntimeError(f"Expected a fresh chat but received existing ID {chat_id}")
        emit({"chat_id": chat_id, "fresh": True, "model": chat.get("modelSelection"),
              "mode": args.mode, "url": f"{client.url}/chat/{chat_id}"})
        if args.title:
            client.call("chats/setTitle", {"chatId": chat_id, "title": args.title})


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
