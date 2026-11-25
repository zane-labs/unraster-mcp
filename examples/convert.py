#!/usr/bin/env python3
"""Convert one PNG/JPEG/WebP into an editable .pptx (2 credits, charged only if delivered).
Usage: UNRASTER_API_KEY=... python3 convert.py slide.png"""
import json, os, sys, time, uuid, urllib.error, urllib.request
from urllib.parse import urljoin, urlparse
BASE = os.environ.get("UNRASTER_API", "https://unraster.ai").rstrip("/")  # same variable as scripts/batch.sh
KEY = os.environ.get("UNRASTER_API_KEY") or sys.exit("Set UNRASTER_API_KEY (https://unraster.ai/developers/api-keys)")
path = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: convert.py <image>")
u = urlparse(BASE)
if u.scheme != "https" and not (u.scheme == "http" and u.hostname in ("localhost", "127.0.0.1")):
    sys.exit("UNRASTER_API must be an https URL (http only for localhost).")
ext = os.path.splitext(path)[1].lower()
mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}.get(ext) or sys.exit("Use a PNG, JPEG or WebP image.")
class NoRedirect(urllib.request.HTTPRedirectHandler):  # never forward the key to another host
    def redirect_request(self, *a): return None
opener = urllib.request.build_opener(NoRedirect)
def call(url, data=None, headers=None):
    h = {"User-Agent": "unraster-example/1.0", **(headers or {})}
    if urlparse(url).netloc == u.netloc:  # send the key only to the API host
        h["Authorization"] = "Bearer " + KEY
    with opener.open(urllib.request.Request(url, data, h), timeout=60) as r:
        return r.read()
idem = os.environ.get("UNRASTER_IDEMPOTENCY_KEY") or str(uuid.uuid4())  # reuse the same key to resume
print("Idempotency-Key:", idem, file=sys.stderr)
tid, stage = None, "submit"
def unsure(why):  # outcome unknown: the task may still run or already be delivered
    sys.exit(f"{why}\nTask ID: {tid or 'not received'}. The result is unknown: it may still be processing or already delivered.\n"
             f"Re-run with UNRASTER_IDEMPOTENCY_KEY={idem} to resume the same task; the same key is never charged twice.")
b = uuid.uuid4().hex
body = (f'--{b}\r\nContent-Disposition: form-data; name="outputs"\r\n\r\npptx\r\n--{b}\r\nContent-Disposition: form-data; name="file"; filename="image{ext}"\r\n'
        f'Content-Type: {mime}\r\n\r\n').encode() + open(path, "rb").read() + f"\r\n--{b}--\r\n".encode()
try:
    task = json.loads(call(BASE + "/v1/conversions", body, {"Idempotency-Key": idem, "Content-Type": "multipart/form-data; boundary=" + b}))
    tid, stage, end = task["id"], "poll", time.time() + 600
    print("Task ID:", tid, file=sys.stderr)
    while task["status"] in ("queued", "processing"):
        if time.time() > end: unsure("Still processing after 10 minutes.")
        time.sleep(3)
        try: task = json.loads(call(f"{BASE}/v1/conversions/{tid}"))
        except urllib.error.HTTPError as e:
            if e.code != 429: raise
            ra = e.headers.get("Retry-After") or ""
            time.sleep(int(ra) if ra.isdigit() else 5)  # rate limited: wait, keep polling
    out = next((o for o in task.get("outputs", []) if o["format"] == "pptx" and o["status"] == "ready"), None)
    if not out: sys.exit(f"No PowerPoint was delivered (status={task['status']}). Undelivered files are not charged.")
    stage = "download"
    dest = os.path.splitext(os.path.basename(path))[0] + ".pptx"
    open(dest, "wb").write(call(urljoin(BASE + "/", out["url"])))
    print("Saved", dest)
except urllib.error.HTTPError as e:
    try: err = json.loads(e.read())["error"]; what = f"HTTP {e.code} {err['code']}: {err['message']}"
    except (ValueError, KeyError): what = f"HTTP {e.code}"
    if stage == "submit" and e.code == 409: sys.exit(f"Rejected: {what}. This Idempotency-Key was already used for a different request; the earlier task, if any, is unaffected. Unset UNRASTER_IDEMPOTENCY_KEY to start a new one.")
    if stage == "submit" and 400 <= e.code < 500 and e.code != 429: sys.exit(f"Rejected: {what} (nothing was charged).")
    unsure("Conversion finished but the download failed: " + what if stage == "download" else "Request error: " + what)
except (OSError, ValueError) as e:  # network error, timeout or unreadable response
    unsure("Download failed: %s" % e if stage == "download" else "Network error or timeout: %s" % e)
