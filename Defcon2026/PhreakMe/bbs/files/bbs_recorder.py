'''  
Interactive CP437-aware BBS recorder for the PhreakMe CTF.

Connects to the local websocat bridge, negotiates Telnet as an ANSI/CP437
terminal, mirrors your keyboard to the BBS, and saves both ANSI and cleaned
transcripts.

Quit locally with Ctrl-].
'''

from __future__ import annotations

import argparse
import asyncio
import contextlib
import json
import os
import re
import sys
import termios
import time
import tty
from datetime import datetime, timezone
from pathlib import Path
from typing import TextIO

import telnetlib3


CSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
OSC_RE = re.compile(r"\x1b\].*?(?:\x07|\x1b\\)", re.DOTALL)
ESC_RE = re.compile(r"\x1b[@-_]")
CONTROL_RE = re.compile(r"[^\x09\x0a\x0d\x20-\U0010ffff]")

PAGER_MARKERS = (
    "[Hit a key]",
    "[hit a key]",
    "Press any key",
    "press any key",
    "--More--",
    "(More)",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def clean_terminal_text(text: str) -> str:
    """Remove ANSI control sequences while preserving CP437-decoded glyphs."""
    text = OSC_RE.sub("", text)
    text = CSI_RE.sub("", text)
    text = ESC_RE.sub("", text)
    text = CONTROL_RE.sub("", text)
    return text.replace("\r\n", "\n").replace("\r", "\n")


def append_event(handle: TextIO, event: str, **details: object) -> None:
    record = {"time": utc_now(), "event": event, **details}
    handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    handle.flush()


class TerminalMode:
    """Put the local Linux terminal into cbreak mode and restore it on exit."""

    def __init__(self) -> None:
        self.fd = sys.stdin.fileno()
        self.original: list | None = None

    def __enter__(self) -> "TerminalMode":
        if sys.stdin.isatty():
            self.original = termios.tcgetattr(self.fd)
            tty.setcbreak(self.fd)
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self.original is not None:
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.original)


async def read_local_key() -> bytes:
    return await asyncio.to_thread(os.read, sys.stdin.fileno(), 1)


async def keyboard_to_bbs(writer, event_log: TextIO) -> None:
    while True:
        key = await read_local_key()
        if not key:
            return

        # Ctrl-] quits locally without sending it to the BBS.
        if key == b"\x1d":
            append_event(event_log, "local_quit")
            return

        if key == b"\n":
            text = "\r"
        elif key == b"\x7f":
            text = "\x08"
        else:
            text = key.decode("latin-1")

        writer.write(text)
        append_event(event_log, "send", hex=key.hex())


async def bbs_to_terminal(
    reader,
    writer,
    ansi_log: TextIO,
    clean_log: TextIO,
    event_log: TextIO,
    auto_more: bool,
) -> None:
    recent = ""
    last_auto = 0.0

    while True:
        try:
            text = await asyncio.wait_for(reader.read(4096), timeout=60)
        except asyncio.TimeoutError:
            append_event(event_log, "read_timeout")
            continue

        if not text:
            append_event(event_log, "remote_eof")
            return

        sys.stdout.write(text)
        sys.stdout.flush()

        ansi_log.write(text)
        ansi_log.flush()

        cleaned = clean_terminal_text(text)
        clean_log.write(cleaned)
        clean_log.flush()

        recent = (recent + cleaned)[-1000:]

        if auto_more and any(marker in recent for marker in PAGER_MARKERS):
            now = time.monotonic()
            if now - last_auto >= 0.75:
                writer.write(" ")
                append_event(event_log, "auto_more", marker="pager")
                last_auto = now
                recent = ""


async def run(args: argparse.Namespace) -> int:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    session_dir = Path(args.output) / f"session-{stamp}"
    session_dir.mkdir(parents=True, exist_ok=False)

    ansi_path = session_dir / "ansi.log"
    clean_path = session_dir / "clean.log"
    event_path = session_dir / "events.jsonl"

    print(f"Logs: {session_dir.resolve()}")
    print("Quit locally with Ctrl-].")
    print(
        f"Connecting to {args.host}:{args.port} as "
        f"term={args.term}, encoding={args.encoding}, {args.cols}x{args.rows}..."
    )

    with (
        ansi_path.open("w", encoding="utf-8", newline="") as ansi_log,
        clean_path.open("w", encoding="utf-8", newline="") as clean_log,
        event_path.open("w", encoding="utf-8") as event_log,
    ):
        append_event(
            event_log,
            "connect_start",
            host=args.host,
            port=args.port,
            term=args.term,
            encoding=args.encoding,
            cols=args.cols,
            rows=args.rows,
        )

        try:
            reader, writer = await asyncio.wait_for(
                telnetlib3.open_connection(
                    host=args.host,
                    port=args.port,
                    encoding=args.encoding,
                    force_binary=True,
                    term=args.term,
                    cols=args.cols,
                    rows=args.rows,
                    connect_minwait=0.05,
                    connect_maxwait=2.0,
                ),
                timeout=args.connect_timeout,
            )
        except (OSError, asyncio.TimeoutError) as exc:
            append_event(event_log, "connect_error", error=str(exc))
            print(f"\nConnection failed: {exc}", file=sys.stderr)
            return 1

        append_event(event_log, "connected")

        with TerminalMode():
            output_task = asyncio.create_task(
                bbs_to_terminal(
                    reader,
                    writer,
                    ansi_log,
                    clean_log,
                    event_log,
                    args.auto_more,
                )
            )
            input_task = asyncio.create_task(keyboard_to_bbs(writer, event_log))

            done, pending = await asyncio.wait(
                {output_task, input_task},
                return_when=asyncio.FIRST_COMPLETED,
            )

            for task in pending:
                task.cancel()
            for task in pending:
                with contextlib.suppress(asyncio.CancelledError):
                    await task

        writer.close()
        wait_closed = getattr(writer, "wait_closed", None)
        if callable(wait_closed):
            with contextlib.suppress(Exception):
                await wait_closed()

        for task in done:
            with contextlib.suppress(asyncio.CancelledError):
                exc = task.exception()
                if exc:
                    append_event(event_log, "task_error", error=repr(exc))
                    print(f"\nTask error: {exc}", file=sys.stderr)
                    return 1

        append_event(event_log, "closed")

    print(f"\nSession saved to: {session_dir.resolve()}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Interactive CP437 Telnet recorder for a local BBS bridge."
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=2323)
    parser.add_argument("--encoding", default="cp437")
    parser.add_argument("--term", default="syncterm")
    parser.add_argument("--cols", type=int, default=80)
    parser.add_argument("--rows", type=int, default=25)
    parser.add_argument("--connect-timeout", type=float, default=15.0)
    parser.add_argument(
        "--output",
        default="bbs-captures",
        help="Parent directory for timestamped session logs.",
    )
    parser.add_argument(
        "--auto-more",
        action="store_true",
        help="Automatically send Space at common pager prompts.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(run(parse_args())))
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        raise SystemExit(130)


path = Path("/mnt/data/bbs_recorder.py")
path.write_text(script, encoding="utf-8")
compile(script, str(path), "exec")
path.chmod(0o755)
print(path)
