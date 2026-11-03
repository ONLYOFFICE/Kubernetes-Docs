#!/usr/bin/env python3
"""Smoke tests for a deployed ONLYOFFICE Docs release (runs after a successful `helm test`).

Talks to Docs from the CI runner through the public API, the same way an integration does:
health, editor static files, CommandService, ConvertService, Document Builder, JWT enforcement.
Request formats and error codes are taken from ONLYOFFICE/server (10.0):
  ConvertService errors: -8 = invalid/missing token, -4 = download error, -3 = conversion error
  CommandService errors: 0 = ok, 1 = unknown key, 6 = invalid/missing token

Stdlib only. Add a check: write a function and decorate it with @check.

Env:
  DS_URL            base URL of the documentserver service       (default http://127.0.0.1:8888)
  JWT_SECRET        jwt.secret of the release                    (default ci-jwt-secret)
  JWT_HEADER        jwt.header of the release                    (default Authorization)
  FILES_URL         in-cluster base URL of the test files server (empty = skip file based checks)
  SMOKE_ONLY        regex, run only checks whose name matches
  CONVERT_TIMEOUT   seconds per conversion (default 180)
"""
import base64
import hashlib
import hmac
import json
import os
import re
import sys
import time
import traceback
import urllib.error
import urllib.request
import uuid

DS_URL = os.environ.get("DS_URL", "http://127.0.0.1:8888").rstrip("/")
JWT_SECRET = os.environ.get("JWT_SECRET", "ci-jwt-secret")
JWT_HEADER = os.environ.get("JWT_HEADER", "Authorization")
FILES_URL = os.environ.get("FILES_URL", "").rstrip("/")
SMOKE_ONLY = os.environ.get("SMOKE_ONLY", "")
CONVERT_TIMEOUT = int(os.environ.get("CONVERT_TIMEOUT", "180"))

# Error codes from ONLYOFFICE/server (Common/sources/utils.js mapAscServerErrorToOldError, commondefines.js)
CONVERT_ERRORS = {
    -1: "unknown error", -2: "conversion timeout", -3: "conversion error",
    -4: "converter could not download the source file", -5: "wrong password", -6: "queue/database error",
    -7: "invalid request parameters", -8: "invalid or missing token", -9: "cannot detect the file format",
    -10: "file size/limits exceeded",
}
COMMAND_ERRORS = {
    1: "unknown document key", 2: "parse error", 3: "internal server error", 4: "not modified",
    5: "unknown command", 6: "invalid or missing token", 7: "token expired",
}


def explain(code, table):
    return f"{code} ({table.get(code, 'see API docs')})"


MAGIC = {
    "pdf": b"%PDF",
    "png": b"\x89PNG",
    "docx": b"PK", "xlsx": b"PK", "pptx": b"PK", "odt": b"PK",
}


class Skip(Exception):
    pass


CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


# ---------------------------------------------------------------- helpers

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def jwt_hs256(payload: dict, secret: str = None) -> str:
    secret = JWT_SECRET if secret is None else secret
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    body = b64url(json.dumps(payload).encode())
    sig = hmac.new(secret.encode(), f"{header}.{body}".encode(), hashlib.sha256).digest()
    return f"{header}.{body}.{b64url(sig)}"


def http(method, path, payload=None, token="valid", timeout=60):
    """token: "valid" | "none" | "wrong" (signed with another secret)."""
    url = path if path.startswith("http") else f"{DS_URL}{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
        if token != "none":
            # Token in the header: request parameters are wrapped into "payload"
            secret = JWT_SECRET if token == "valid" else JWT_SECRET + "-wrong"
            req.add_header(JWT_HEADER, "Bearer " + jwt_hs256({"payload": payload}, secret))
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def get(path, timeout=60):
    return http("GET", path, timeout=timeout)


def need_files():
    if not FILES_URL:
        raise Skip("FILES_URL is not set")


def download(url, expect_ext):
    status, body = get(url, timeout=120)
    assert status == 200, f"download {url}: HTTP {status}"
    magic = MAGIC.get(expect_ext)
    if magic:
        assert body.startswith(magic), f"result is not {expect_ext}: starts with {body[:8]!r}"
    assert len(body) > 100, f"result is suspiciously small: {len(body)} bytes"
    return body


def convert(src, filetype, outputtype, async_=False, **extra):
    """ConvertService.ashx; returns (result bytes, response json)."""
    payload = {
        "async": async_,
        "filetype": filetype,
        "outputtype": outputtype,
        "key": uuid.uuid4().hex,
        "title": f"smoke.{filetype}",
        "url": f"{FILES_URL}/{src}",
        **extra,
    }
    deadline = time.monotonic() + CONVERT_TIMEOUT
    polls = 0
    while True:
        status, body = http("POST", "/ConvertService.ashx", payload, timeout=CONVERT_TIMEOUT)
        assert status == 200, f"HTTP {status}: {body[:300]!r}"
        data = json.loads(body)
        assert "error" not in data, \
            f"ConvertService error {explain(data['error'], CONVERT_ERRORS)} for {src} -> {outputtype}"
        if data.get("endConvert"):
            break
        # async: the same request (same key) polls the status
        assert async_, f"sync conversion returned endConvert=false: {data}"
        assert time.monotonic() < deadline, f"conversion not finished in {CONVERT_TIMEOUT}s: {data}"
        polls += 1
        time.sleep(1)
    result_ext = data.get("fileType") or outputtype
    result = download(data["fileUrl"], result_ext)
    return result, data, polls


def command(payload, token="valid"):
    status, body = http("POST", "/coauthoring/CommandService.ashx", payload, token=token)
    assert status == 200, f"HTTP {status}: {body[:300]!r}"
    data = json.loads(body)
    if data.get("error"):
        data["error_meaning"] = COMMAND_ERRORS.get(data["error"], "see API docs")
    return data


# ---------------------------------------------------------------- health and static

@check
def healthcheck():
    status, body = get("/healthcheck")
    assert status == 200 and body.strip() == b"true", f"healthcheck: HTTP {status} {body[:200]!r}"


@check
def editor_static_files():
    """Files the editors load in the browser: a broken image gives a blank editor with a green healthcheck."""
    files = {
        "/web-apps/apps/api/documents/api.js": (b"DocsAPI", 1_000),
        "/web-apps/apps/documenteditor/main/index.html": (b"<html", 500),
        "/web-apps/apps/spreadsheeteditor/main/index.html": (b"<html", 500),
        "/web-apps/apps/presentationeditor/main/index.html": (b"<html", 500),
        "/sdkjs/word/sdk-all-min.js": (None, 100_000),
        "/sdkjs/cell/sdk-all-min.js": (None, 100_000),
        "/sdkjs/slide/sdk-all-min.js": (None, 100_000),
        "/sdkjs/common/AllFonts.js": (None, 1_000),
    }
    problems = []
    for path, (marker, min_size) in files.items():
        status, body = get(path)
        if status != 200:
            problems.append(f"{path}: HTTP {status}")
        elif len(body) < min_size:
            problems.append(f"{path}: only {len(body)} bytes")
        elif marker and marker not in body[:20_000].lower() and marker not in body[:20_000]:
            problems.append(f"{path}: no {marker!r} in content")
    assert not problems, "; ".join(problems)


# ---------------------------------------------------------------- CommandService

@check
def command_version():
    data = command({"c": "version"})
    assert data.get("error") == 0, f"CommandService answered {data}"
    assert data.get("version"), f"no version in the answer: {data}"
    print(f"    Docs version: {data['version']}")


@check
def command_license():
    data = command({"c": "license"})
    assert data.get("error") == 0, f"CommandService answered {data}"
    server = data.get("server") or {}
    assert "packageType" in server, f"no license server info: {data}"
    print(f"    packageType={server.get('packageType')} resultType={server.get('resultType')} "
          f"build={server.get('buildVersion')}.{server.get('buildNumber')} quota={data.get('quota')}")


@check
def command_forgotten_list():
    """Lists files in storage: touches the shared storage through the server."""
    data = command({"c": "getForgottenList"})
    assert data.get("error") == 0, f"CommandService answered {data}"
    assert isinstance(data.get("keys"), list), f"no keys list: {data}"


@check
def command_unknown_document():
    """info for a document that is not open: goes through the editor state (Redis/DB) and must say 'unknown key'."""
    data = command({"c": "info", "key": "smoke-" + uuid.uuid4().hex})
    assert data.get("error") == 1, f"expected error 1 (unknown key), got {data}"


# ---------------------------------------------------------------- JWT enforcement

@check
def jwt_command_without_token():
    data = command({"c": "version"}, token="none")
    assert data.get("error") == 6, f"request without token must be rejected with error 6, got {data}"


@check
def jwt_command_wrong_secret():
    data = command({"c": "version"}, token="wrong")
    assert data.get("error") == 6, f"request with a wrong token must be rejected with error 6, got {data}"


@check
def jwt_convert_without_token():
    payload = {"async": False, "filetype": "txt", "outputtype": "pdf", "key": uuid.uuid4().hex,
               "url": f"{FILES_URL or DS_URL}/sample.txt"}
    status, body = http("POST", "/ConvertService.ashx", payload, token="none")
    data = json.loads(body)
    assert data.get("error") == -8, f"conversion without token must be rejected with error -8, got {data}"


# ---------------------------------------------------------------- ConvertService

def conversion(src, filetype, outputtype, **extra):
    def run():
        need_files()
        result, data, _ = convert(src, filetype, outputtype, **extra)
        print(f"    {src} -> {data.get('fileType') or outputtype}: {len(result)} bytes")
    run.__name__ = f"convert_{filetype}_to_{outputtype}" + ("_thumbnail" if "thumbnail" in extra else "")
    return check(run)


conversion("sample.txt", "txt", "pdf")
conversion("sample.docx", "docx", "pdf")
conversion("sample.xlsx", "xlsx", "pdf")
conversion("sample.pptx", "pptx", "pdf")
conversion("sample.docx", "docx", "odt")
conversion("sample.csv", "csv", "xlsx")
conversion("sample.pptx", "pptx", "png", thumbnail={"aspect": 1, "first": True, "width": 320, "height": 240})


@check
def convert_async_with_polling():
    need_files()
    result, data, polls = convert("sample.docx", "docx", "pdf", async_=True)
    print(f"    finished after {polls} status poll(s), {len(result)} bytes")


# ---------------------------------------------------------------- Document Builder

@check
def docbuilder():
    need_files()
    payload = {"async": False, "key": uuid.uuid4().hex, "url": f"{FILES_URL}/builder.docbuilder"}
    status, body = http("POST", "/docbuilder", payload, timeout=CONVERT_TIMEOUT)
    assert status == 200, f"HTTP {status}: {body[:300]!r}"
    data = json.loads(body)
    assert "error" not in data, f"docbuilder error {explain(data['error'], CONVERT_ERRORS)}"
    assert data.get("end") and data.get("urls"), f"docbuilder did not finish: {data}"
    name, url = next(iter(data["urls"].items()))
    result = download(url, "docx")
    print(f"    {name}: {len(result)} bytes")


# ---------------------------------------------------------------- runner

def main():
    selected = [fn for fn in CHECKS if not SMOKE_ONLY or re.search(SMOKE_ONLY, fn.__name__)]
    results = []
    for fn in selected:
        name = fn.__name__
        started = time.monotonic()
        try:
            fn()
            outcome = "PASS"
        except Skip as e:
            outcome = f"SKIP ({e})"
        except Exception:  # noqa: BLE001 - report every failure, keep going
            outcome = "FAIL"
            traceback.print_exc()
        took = time.monotonic() - started
        results.append((name, outcome, took))
        print(f"{outcome:5} {name} ({took:.1f}s)", flush=True)

    failed = [r for r in results if r[1] == "FAIL"]
    passed = [r for r in results if r[1] == "PASS"]
    print(f"\n{len(passed)} passed, {len(failed)} failed, {len(results) - len(passed) - len(failed)} skipped")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        icon = {"PASS": "✅", "FAIL": "❌"}
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"### Smoke tests ({DS_URL})\n| check | result | time |\n|---|---|---|\n")
            for name, outcome, took in results:
                f.write(f"| `{name}` | {icon.get(outcome, '⏭️')} {outcome} | {took:.1f}s |\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

