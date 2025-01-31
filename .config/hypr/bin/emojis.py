#!/usr/bin/env python3

import select
import sys
# import unicodedata

try:
    from emoji import EMOJI_DATA
except ModuleNotFoundError:
    print("Please install the emoji package:\n  pip install emoji")
    sys.exit(1)
except ImportError:
    print("Please update the emoji package:\n  pip install --upgrade emoji")
    sys.exit(1)


def list_emojis():
    for emoji, name in EMOJI_DATA.items():
        # name = unicodedata.name(char)
        name = name["en"]
        print(f"{emoji} {name}\r{name.upper()}")


def sanitize_emoji() -> str:
    in_readable, _, _ = select.select([sys.stdin], [], [], 20)
    if in_readable:
        return sys.stdin.read().strip().split()[0]
    sys.exit(1)


def main():
    argv = sys.argv[1:]
    subc = argv[0] if len(argv) > 0 else "list"

    if subc == "decode":
        print(sanitize_emoji(), end="")
        return

    list_emojis()


if __name__ == "__main__":
    main()
