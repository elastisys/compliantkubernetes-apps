"""
Reusable components for the QA scripts.
"""

import argparse
import json
import os
import pty
import select
import subprocess
import sys
from argparse import ArgumentParser
from contextlib import suppress
from contextvars import ContextVar
from dataclasses import dataclass
from functools import partial, wraps
from itertools import count
from pathlib import Path
from threading import Thread
from typing import Any, Callable, Iterator, TextIO

# JSON is a complex type, but for our purposes this will suffice
Jsonable = dict | list | str


@dataclass(frozen=True)
class AppsConfig:
    """Handles config operations"""

    path: Path

    def set(self, key: str, value: Jsonable, merge: bool = True) -> None:
        """Set a config key (with merge)"""
        _run(
            "yq",
            "-i",
            f".{key} = .{key} * {json.dumps(value)}" if merge else f".{key} = {json.dumps(value)}",
            self.path.resolve().as_posix(),
        )

    def get(self, key: str) -> list | dict:
        """Get a config key"""
        # fmt: off
        return (
            _get_json(
                "yq",
                "--output-format", "json",
                "--nul-output",
                "--indent", "0",
                f".{key}",
                self.path.resolve().as_posix(),
            )
            or {}
        )
        # fmt: on


@dataclass(frozen=True)
class StepArgs:
    """Holds the step execution arguments"""

    dry_run: bool
    start_at: int
    interactive: bool

    @staticmethod
    def add_parser_args(parser: ArgumentParser) -> None:
        parser.add_argument(
            "-n",
            "--dry-run",
            action=argparse.BooleanOptionalAction,
            help="doesn't perform any effects; just lists steps.",
        )
        parser.add_argument("-s", "--step", type=int, required=False, help="start at step.")
        parser.add_argument(
            "-m",
            "--interactive",
            action=argparse.BooleanOptionalAction,
            help="manually confirm each step.",
        )

    @classmethod
    def from_parsed_args(cls, args: argparse.Namespace) -> "StepArgs":
        return cls(
            dry_run=args.dry_run,
            start_at=(args.step or 1),
            interactive=args.interactive,
        )


STEP_ARGS: ContextVar[StepArgs] = ContextVar("args")
STEP_COUNTER: Iterator[int] = count(1)


def _step[**P, R](func: Callable[P, R], doc_suffix: str = "") -> Callable[P, R | None]:
    step_no = next(STEP_COUNTER)
    setattr(func, "__step_no__", step_no)

    step_doc = f"Step {step_no}: {func.__doc__} {doc_suffix}".rstrip()
    setattr(func, "__step_doc__", step_doc)

    return _effect(func)


def _effect[**P, R](func: Callable[P, R]) -> Callable[P, R | None]:
    @wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R | None:
        step_args = STEP_ARGS.get()
        if (step_doc := getattr(func, "__step_doc__", None)) is not None:
            if getattr(func, "__step_no__") < step_args.start_at:
                print(f"\033[90m{step_doc} [skipped]\033[0m", file=sys.stderr)
                return None

            print(f"\033[95m{step_doc}\033[0m", file=sys.stderr)

            if not step_args.dry_run and step_args.interactive and not _confirm("Perform step?"):
                return None

        if step_args.dry_run:
            return None

        return func(*args, **kwargs)

    return wrapper


@_effect
def _run(*command: str, **kwargs: Any) -> None:
    """
    Poor man's bash: just a subprocess.Popen at its core, but with
    its standard descriptors wired to a pseudoterminal.

    This allows the child process to output colors and accept user input.
    """
    try:
        parent, child = pty.openpty()

        process = subprocess.Popen(
            command,
            stdin=child,
            stdout=child,
            stderr=child,
            **kwargs,
        )

        # Close the child end in the parent process to avoid deadlock
        os.close(child)

        # If we get a file descriptor (int), mirror it right out
        # but if we're passed TextIO instances (like sys.stdin), call the `.fileno()` method
        # to obtain the file descriptor.
        def get_fd(stream: TextIO | int) -> int:
            return stream if isinstance(stream, int) else stream.fileno()

        def wire_streams(in_s: TextIO | int, out_s: TextIO | int) -> None:
            with suppress(OSError, IOError):

                # Popen.poll returns None as long as the child process is alive
                while process.poll() is None:

                    # We only pass the stream that we're interested in reading from in
                    # to the 'read list' argument of select, then go ahead and pipe the read
                    # data to the output stream (when selected).
                    if in_s in select.select([in_s], [], [], 0.1)[0]:
                        data = os.read(get_fd(in_s), 1024)
                        if data:
                            os.write(get_fd(out_s), data)

        # The `partial` usage here just gives us back a function that has all the arguments
        # set, but hasn't been called yet.
        #
        # We're starting separate threads for:
        # - passing reads from our stdin to the PTY's parent
        # - passing reads from the PTY's parent to our stdout
        Thread(target=partial(wire_streams, sys.stdin, parent), daemon=True).start()
        Thread(target=partial(wire_streams, parent, sys.stdout), daemon=True).start()

        return_code = process.wait()

        # Process remaining output
        with suppress(OSError):
            remaining = os.read(parent, 1024)
            if remaining:
                os.write(sys.stdout.fileno(), remaining)
                sys.stdout.flush()

        os.close(parent)
        if return_code != 0:
            sys.exit(return_code)

    except Exception as e:
        print(f"Error running command: {e}", file=sys.stderr)

        # Equivalent of `set -e`. Any error means execution is halted.
        sys.exit(1)


@_effect
def _get_json(*command: str, **kwargs: Any) -> list | dict:
    stripped = str(subprocess.check_output(command, text=True, **kwargs)).strip(" \x00")
    return json.loads(stripped)


def _set_secret_key(secret_path: Path, key: str, value: Jsonable) -> None:
    _run(
        "sops",
        "--set",
        f"{key} {json.dumps(value)}",
        secret_path.resolve().as_posix(),
    )


def _confirm(question: str) -> bool:
    prompt = f":: {question} [Y/n] "

    while True:
        answer = input(prompt).lower().strip()
        if not answer:
            print(f"\033[A\033[K{prompt}y")
            return True
        if answer in ["y", "yes"]:
            return True
        if answer in ["n", "no"]:
            return False
        print("Please enter 'y' or 'n'")
