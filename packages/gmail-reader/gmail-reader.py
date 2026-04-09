#!/usr/bin/env python3
"""
Gmail Reader for reMarkable 2 + NetSurf.
Fetches the last 30 emails via IMAP and generates a static HTML page
that looks like Gmail's interface. Opens in NetSurf as a local file.

Usage:
  1. Create config: ~/.config/gmail-reader.conf
     [gmail]
     email = yourname@gmail.com
     app_password = xxxx-xxxx-xxxx-xxxx

  2. Run: python3 gmail-reader.py
  3. Open in NetSurf: file:///home/root/gmail/inbox.html
"""

import configparser
import email
import email.header
import email.utils
import html
import imaplib
import os
import re
import sys
import time
from datetime import datetime, timezone

# ── Config ──────────────────────────────────────────────────────────

CONFIG_PATH = os.path.expanduser("~/.config/gmail-reader.conf")
OUTPUT_DIR = os.path.expanduser("~/gmail")
INBOX_HTML = os.path.join(OUTPUT_DIR, "inbox.html")
MSG_DIR = os.path.join(OUTPUT_DIR, "msg")
NUM_EMAILS = 30

# ── Helpers ─────────────────────────────────────────────────────────

def decode_header(raw):
    """Decode an email header into a plain string."""
    if raw is None:
        return ""
    parts = email.header.decode_header(raw)
    result = []
    for data, charset in parts:
        if isinstance(data, bytes):
            result.append(data.decode(charset or "utf-8", errors="replace"))
        else:
            result.append(data)
    return " ".join(result)


def parse_date(raw):
    """Parse email date into a datetime object."""
    if not raw:
        return datetime.now()
    try:
        tt = email.utils.parsedate_to_datetime(raw)
        return tt
    except Exception:
        return datetime.now()


def format_date_short(dt):
    """Format date for inbox list: today shows time, else shows date."""
    now = datetime.now(dt.tzinfo if dt.tzinfo else None)
    if dt.date() == now.date():
        return dt.strftime("%H:%M")
    elif dt.year == now.year:
        return dt.strftime("%b %d")
    else:
        return dt.strftime("%Y. %b %d")


def format_date_full(dt):
    """Full date for message view."""
    return dt.strftime("%Y. %b %d. %H:%M")


def get_sender_name(raw):
    """Extract just the display name from a From header."""
    name, addr = email.utils.parseaddr(decode_header(raw))
    if name:
        return name
    return addr


def get_sender_full(raw):
    """Full sender: name <email>."""
    name, addr = email.utils.parseaddr(decode_header(raw))
    if name:
        return f"{name} <{addr}>"
    return addr


def extract_text(msg):
    """Extract plain text body from an email message."""
    if msg.is_multipart():
        # Try text/plain first, then text/html
        text_part = None
        html_part = None
        for part in msg.walk():
            ct = part.get_content_type()
            cd = str(part.get("Content-Disposition", ""))
            if "attachment" in cd:
                continue
            if ct == "text/plain" and text_part is None:
                text_part = part
            elif ct == "text/html" and html_part is None:
                html_part = part

        if text_part:
            payload = text_part.get_payload(decode=True)
            charset = text_part.get_content_charset() or "utf-8"
            return payload.decode(charset, errors="replace")
        elif html_part:
            payload = html_part.get_payload(decode=True)
            charset = html_part.get_content_charset() or "utf-8"
            raw_html = payload.decode(charset, errors="replace")
            # Strip HTML tags for plain text display
            text = re.sub(r'<style[^>]*>.*?</style>', '', raw_html, flags=re.DOTALL)
            text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
            text = re.sub(r'<br\s*/?>', '\n', text, flags=re.IGNORECASE)
            text = re.sub(r'</?p[^>]*>', '\n', text, flags=re.IGNORECASE)
            text = re.sub(r'<[^>]+>', '', text)
            text = html.unescape(text)
            return text.strip()
        return "(No text content)"
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            return payload.decode(charset, errors="replace")
        return "(No content)"


def snippet(text, maxlen=80):
    """Get a short preview of the email body."""
    line = text.replace("\n", " ").replace("\r", " ").strip()
    line = re.sub(r'\s+', ' ', line)
    if len(line) > maxlen:
        return line[:maxlen] + "..."
    return line


# ── IMAP fetch ──────────────────────────────────────────────────────

def fetch_emails(email_addr, app_password):
    """Connect to Gmail IMAP and fetch the last N emails."""
    print(f"Connecting to Gmail IMAP...")
    imap = imaplib.IMAP4_SSL("imap.gmail.com", 993)
    imap.login(email_addr, app_password)
    imap.select("INBOX", readonly=True)

    # Search for all emails, get the last N
    status, data = imap.search(None, "ALL")
    if status != "OK":
        print("Failed to search inbox")
        return []

    msg_ids = data[0].split()
    if not msg_ids:
        print("Inbox is empty")
        return []

    # Get last N message IDs
    last_ids = msg_ids[-NUM_EMAILS:]
    last_ids.reverse()  # newest first

    emails = []
    total = len(last_ids)
    for i, mid in enumerate(last_ids):
        print(f"  Fetching {i+1}/{total}...", end="\r")
        status, msg_data = imap.fetch(mid, "(RFC822 FLAGS)")
        if status != "OK":
            continue
        raw = msg_data[0][1]
        msg = email.message_from_bytes(raw)

        # Check FLAGS for \Seen
        flags_raw = msg_data[0][0].decode("utf-8", errors="replace")
        is_read = "\\Seen" in flags_raw

        sender_name = get_sender_name(msg["From"])
        sender_full = get_sender_full(msg["From"])
        subject = decode_header(msg["Subject"]) or "(No subject)"
        date = parse_date(msg["Date"])
        to_addr = decode_header(msg.get("To", ""))
        body = extract_text(msg)

        emails.append({
            "id": mid.decode(),
            "sender_name": sender_name,
            "sender_full": sender_full,
            "subject": subject,
            "date": date,
            "date_short": format_date_short(date),
            "date_full": format_date_full(date),
            "to": to_addr,
            "body": body,
            "snippet": snippet(body),
            "is_read": is_read,
        })

    print(f"  Fetched {len(emails)} emails.     ")
    imap.close()
    imap.logout()
    return emails


# ── HTML generation ─────────────────────────────────────────────────

INBOX_CSS = """
body { font-family: sans-serif; margin: 0; padding: 0; background: #fff; color: #000; }
.header { background: #333; color: #fff; padding: 10px 16px; font-size: 20px; }
.header span { color: #aaa; font-size: 14px; margin-left: 10px; }
.toolbar { background: #eee; padding: 6px 16px; border-bottom: 1px solid #ccc; font-size: 13px; color: #555; }
.row { display: table; width: 100%; border-bottom: 1px solid #e0e0e0; }
.row:hover { background: #f5f5f5; }
.row a { display: table; width: 100%; text-decoration: none; color: #000; }
.col { display: table-cell; padding: 10px 8px; vertical-align: middle; }
.col-sender { width: 22%; font-size: 14px; white-space: nowrap; overflow: hidden; }
.col-content { width: 62%; }
.col-date { width: 16%; text-align: right; font-size: 13px; color: #555; white-space: nowrap; }
.subject { font-size: 14px; }
.snippet { font-size: 13px; color: #666; margin-left: 6px; }
.unread .col-sender, .unread .subject { font-weight: bold; }
.footer { padding: 12px 16px; text-align: center; color: #888; font-size: 12px; border-top: 1px solid #e0e0e0; }
"""

MSG_CSS = """
body { font-family: sans-serif; margin: 0; padding: 0; background: #fff; color: #000; }
.header { background: #333; color: #fff; padding: 10px 16px; font-size: 20px; }
.back { display: inline-block; padding: 6px 16px; background: #eee; border-bottom: 1px solid #ccc; font-size: 14px; text-decoration: none; color: #333; }
.back:hover { background: #ddd; }
.msg-header { padding: 14px 16px; border-bottom: 1px solid #e0e0e0; }
.msg-subject { font-size: 20px; font-weight: bold; margin-bottom: 10px; }
.msg-meta { font-size: 13px; color: #555; line-height: 1.6; }
.msg-from { font-size: 14px; font-weight: bold; color: #000; }
.msg-body { padding: 16px; font-size: 14px; line-height: 1.6; white-space: pre-wrap; word-wrap: break-word; }
"""


def generate_inbox_html(emails):
    """Generate the inbox list HTML page."""
    rows = []
    for i, em in enumerate(emails):
        unread_cls = "" if em["is_read"] else " unread"
        fname = f"msg/{em['id']}.html"
        rows.append(f"""<div class="row{unread_cls}"><a href="{fname}">
  <div class="col col-sender">{html.escape(em['sender_name'])}</div>
  <div class="col col-content"><span class="subject">{html.escape(em['subject'])}</span><span class="snippet"> - {html.escape(em['snippet'])}</span></div>
  <div class="col col-date">{html.escape(em['date_short'])}</div>
</a></div>""")

    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Gmail - Inbox</title>
<style>{INBOX_CSS}</style></head><body>
<div class="header">Gmail<span>Inbox ({len(emails)})</span></div>
<div class="toolbar">Frissitve: {now} | Frissiteshez futtasd: gmail-reader.py</div>
{''.join(rows)}
<div class="footer">Gmail Reader for reMarkable | {len(emails)} email</div>
</body></html>"""


def generate_msg_html(em):
    """Generate a single email view HTML page."""
    body_escaped = html.escape(em["body"])
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{html.escape(em['subject'])}</title>
<style>{MSG_CSS}</style></head><body>
<div class="header">Gmail</div>
<a class="back" href="../inbox.html">&lt; Vissza az inboxhoz</a>
<div class="msg-header">
  <div class="msg-subject">{html.escape(em['subject'])}</div>
  <div class="msg-meta">
    <div class="msg-from">{html.escape(em['sender_full'])}</div>
    <div>Cimzett: {html.escape(em['to'])}</div>
    <div>{html.escape(em['date_full'])}</div>
  </div>
</div>
<div class="msg-body">{body_escaped}</div>
</body></html>"""


# ── Main ────────────────────────────────────────────────────────────

def main():
    # Load config
    if not os.path.exists(CONFIG_PATH):
        print(f"Config not found: {CONFIG_PATH}")
        print(f"Create it with:")
        print(f"  mkdir -p ~/.config")
        print(f"  cat > {CONFIG_PATH} << 'EOF'")
        print(f"  [gmail]")
        print(f"  email = yourname@gmail.com")
        print(f"  app_password = xxxx-xxxx-xxxx-xxxx")
        print(f"  EOF")
        sys.exit(1)

    cfg = configparser.ConfigParser()
    cfg.read(CONFIG_PATH)

    try:
        email_addr = cfg["gmail"]["email"]
        app_password = cfg["gmail"]["app_password"]
    except KeyError:
        print(f"Missing 'email' or 'app_password' in {CONFIG_PATH}")
        sys.exit(1)

    # Create output directories
    os.makedirs(MSG_DIR, exist_ok=True)

    # Fetch emails
    emails = fetch_emails(email_addr, app_password)
    if not emails:
        print("No emails fetched.")
        return

    # Generate inbox HTML
    with open(INBOX_HTML, "w", encoding="utf-8") as f:
        f.write(generate_inbox_html(emails))
    print(f"Inbox: {INBOX_HTML}")

    # Generate individual message pages
    for em in emails:
        msg_path = os.path.join(MSG_DIR, f"{em['id']}.html")
        with open(msg_path, "w", encoding="utf-8") as f:
            f.write(generate_msg_html(em))

    print(f"Generated {len(emails)} message pages in {MSG_DIR}/")
    print(f"Open in NetSurf: file://{INBOX_HTML}")


if __name__ == "__main__":
    main()
