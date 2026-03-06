#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def normalize_same_site(value):
    if value is None:
        return "Lax"
    mapping = {
        "lax": "Lax",
        "strict": "Strict",
        "none": "None",
    }
    return mapping.get(str(value).lower(), "Lax")


def main():
    parser = argparse.ArgumentParser(
        description="Convert exported browser cookies JSON into Playwright storage state."
    )
    parser.add_argument("--input", required=True, help="Path to cookies JSON array")
    parser.add_argument("--output", required=True, help="Path to storageState JSON")
    args = parser.parse_args()

    raw = json.loads(Path(args.input).read_text())
    cookies = []
    for cookie in raw:
        domain = cookie["domain"]
        path = cookie.get("path", "/")
        expires = cookie.get("expirationDate")
        if expires is None:
            expires = -1
        else:
            expires = int(float(expires))
        cookies.append(
            {
                "name": cookie["name"],
                "value": cookie["value"],
                "domain": domain,
                "path": path,
                "expires": expires,
                "httpOnly": bool(cookie.get("httpOnly", False)),
                "secure": bool(cookie.get("secure", False)),
                "sameSite": normalize_same_site(cookie.get("sameSite")),
            }
        )

    storage_state = {
        "cookies": cookies,
        "origins": [],
    }
    Path(args.output).write_text(json.dumps(storage_state, indent=2))


if __name__ == "__main__":
    main()
