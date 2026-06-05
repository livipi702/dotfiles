#!/usr/bin/env python3
import argparse
import asyncio
import hashlib
import json
import os
import re
import shutil
import sys
import threading
import time
import zipfile
from collections import defaultdict, deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from urllib.parse import urljoin, urlparse

# ── dependency check ────────────────────────────────────────────────────────────
try:
    import httpx
    import trafilatura
    from bs4 import BeautifulSoup
    from markdownify import markdownify as _to_md
except ImportError as exc:
    sys.exit(
        f"Missing dependency: {exc}\n"
        "Install everything at once:\n"
        "    pip install httpx beautifulsoup4 trafilatura markdownify lxml"
    )

try:
    import lxml
except ImportError:
    sys.exit("Missing dependency: pip install lxml")

try:
    from playwright.async_api import async_playwright
    from playwright.sync_api import sync_playwright

    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False

# ── constants ───────────────────────────────────────────────────────────────────
VERSION = "6.0.0"

IGNORE_PATH_FRAGMENTS = [
    "login",
    "logout",
    "signup",
    "sign-up",
    "sign_up",
    "register",
    "registration",
    "pricing",
    "plans",
    "account",
    "dashboard",
    "billing",
    "invoice",
    "feedback",
    "search",
    "404",
]

STRIP_SELECTORS = [
    "nav",
    "header",
    "footer",
    "aside",
    "[role='navigation']",
    "[role='banner']",
    "[role='contentinfo']",
    "[role='complementary']",
    "[role='search']",
    ".sidebar",
    ".side-bar",
    "#sidebar",
    "#side-bar",
    ".nav",
    ".navbar",
    "#nav",
    "#navbar",
    "#navigation",
    ".toc",
    ".table-of-contents",
    "#toc",
    ".header",
    "#header",
    ".footer",
    "#footer",
    ".breadcrumb",
    ".breadcrumbs",
    "#breadcrumb",
    ".cookie",
    ".cookie-banner",
    ".cookie-notice",
    ".announcement",
    ".banner",
    ".alert-bar",
    ".feedback",
    ".feedback-widget",
    ".feedback-form",
    ".newsletter",
    ".subscribe",
    ".pagination",
    "#pagination",
    ".social",
    ".share-buttons",
    ".social-share",
    ".related",
    ".related-articles",
    ".related-posts",
    ".ads",
    ".advertisement",
    "[class*='sponsor']",
    "script",
    "style",
    "noscript",
    "iframe",
    "svg",
    "form",
    "[role='form']",
]

MAIN_CONTENT_SELECTORS = [
    "main",
    "article",
    "[role='main']",
    "#main-content",
    "#main_content",
    "#content",
    ".main-content",
    ".main_content",
    ".docs-content",
    ".documentation",
    ".doc-content",
    ".article-content",
    ".markdown-body",
    ".prose",
    ".content-body",
    "#docs",
    ".docs",
    "#documentation",
    "[class*='content'][class*='main']",
    "[class*='page'][class*='content']",
    "body",
]

BREADCRUMB_SELECTORS = [
    "[aria-label='breadcrumb']",
    "[aria-label='Breadcrumb']",
    "[aria-label='breadcrumbs']",
    "nav.breadcrumb",
    "nav.breadcrumbs",
    "ol.breadcrumb",
    ".breadcrumb",
    ".breadcrumbs",
    "#breadcrumb",
    "[itemtype*='BreadcrumbList']",
]

ASSET_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".svg",
    ".webp",
    ".ico",
    ".bmp",
    ".css",
    ".js",
    ".ts",
    ".map",
    ".woff",
    ".woff2",
    ".ttf",
    ".eot",
    ".otf",
    ".pdf",
    ".doc",
    ".docx",
    ".xls",
    ".xlsx",
    ".zip",
    ".tar",
    ".gz",
    ".bz2",
    ".rar",
    ".mp4",
    ".mp3",
    ".avi",
    ".mov",
    ".wav",
    ".json",
    ".xml",
    ".yaml",
    ".yml",
}

SITEMAP_PATHS = [
    "/sitemap.xml",
    "/sitemap_index.xml",
    "/sitemaps.xml",
    "/sitemap-index.xml",
    "/docs/sitemap.xml",
    "/api/sitemap.xml",
]

RETRY_STATUS_CODES = {429, 500, 502, 503, 504}
MAX_RETRIES = 3
BACKOFF_BASE = 1.0
USER_AGENT = (
    "doc-ingester/4.0 (documentation archiver; github.com/example/doc-ingester)"
)
PAGE_DIVIDER = "\n---\n"

_SEARCH_STOPWORDS = {
    "the",
    "a",
    "an",
    "and",
    "or",
    "but",
    "in",
    "on",
    "at",
    "to",
    "for",
    "of",
    "with",
    "by",
    "is",
    "are",
    "was",
    "were",
    "be",
    "been",
    "have",
    "has",
    "had",
    "do",
    "does",
    "did",
    "will",
    "would",
    "should",
    "could",
    "may",
    "might",
    "shall",
    "can",
    "this",
    "that",
    "these",
    "those",
    "it",
    "its",
    "from",
    "as",
    "if",
    "not",
    "no",
    "so",
    "up",
    "about",
    "into",
    "through",
    "during",
    "before",
    "after",
    "above",
    "below",
    "between",
    "each",
    "how",
    "what",
    "when",
    "where",
    "who",
    "which",
    "your",
    "you",
    "we",
    "us",
    "our",
    "they",
    "them",
    "their",
    "page",
    "see",
    "also",
    "use",
    "using",
    "used",
    "get",
    "set",
    "new",
    "more",
    "all",
    "any",
    "one",
    "two",
    "three",
    "other",
    "following",
    "example",
    "note",
    "ref",
}

_CODE_FENCE = re.compile(r"```([a-zA-Z0-9_+\-]+)?[ \t]*\n(.*?)```", re.DOTALL)

_NAV_PATTERNS = [
    re.compile(
        r"^(Next|Previous|Back|Continue|Last updated)[:\s].*$",
        re.MULTILINE | re.IGNORECASE,
    ),
    re.compile(
        r"^(Was this (page|doc|article) helpful|Edit this page|Suggest an edit|View (source|on GitHub)).*$",
        re.MULTILINE | re.IGNORECASE,
    ),
    re.compile(r"^On this page\s*$", re.MULTILINE | re.IGNORECASE),
    re.compile(
        r"^\[.*?(next|previous|back|↑|top)\b.*?\]\(.*?\)\s*$",
        re.MULTILINE | re.IGNORECASE,
    ),
]


# ── HTTP cache ──────────────────────────────────────────────────────────────────
class Cache:
    def __init__(self, cache_dir: Path) -> None:
        self.cache_dir = cache_dir
        cache_dir.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()

    def _path(self, url: str) -> Path:
        key = hashlib.sha256(url.encode()).hexdigest()
        return self.cache_dir / f"{key}.json"

    def get(self, url: str) -> Optional[Dict]:
        p = self._path(url)
        if p.exists():
            try:
                return json.loads(p.read_text(encoding="utf-8"))
            except Exception:
                return None
        return None

    def put(
        self, url: str, etag: Optional[str], last_modified: Optional[str], html: str
    ) -> None:
        entry = {
            "url": url,
            "etag": etag,
            "last_modified": last_modified,
            "html": html,
            "cached_at": datetime.now(timezone.utc).isoformat(),
        }
        try:
            with self._lock:
                self._path(url).write_text(
                    json.dumps(entry, ensure_ascii=False), encoding="utf-8"
                )
        except Exception:
            pass


class _CachedResponse:
    def __init__(self, html: str, from_304: bool = False) -> None:
        self.status_code = 200
        self.text = html
        self._headers: Dict[str, str] = {"content-type": "text/html; charset=utf-8"}
        self.from_304 = from_304

    @property
    def headers(self) -> Dict[str, str]:
        return self._headers

    def raise_for_status(self) -> None:
        pass


# ── HTTP helpers ────────────────────────────────────────────────────────────────
def make_client(timeout: float = 20.0) -> httpx.Client:
    return httpx.Client(
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        },
        timeout=timeout,
        follow_redirects=True,
    )


def fetch(
    client: httpx.Client,
    url: str,
    cache: Optional[Cache] = None,
    silent_404: bool = True,
) -> Optional[Any]:
    cached = cache.get(url) if cache else None
    conditional_headers: Dict[str, str] = {}
    if cached:
        if cached.get("etag"):
            conditional_headers["If-None-Match"] = cached["etag"]
        if cached.get("last_modified"):
            conditional_headers["If-Modified-Since"] = cached["last_modified"]

    for attempt in range(MAX_RETRIES + 1):
        try:
            resp = client.get(url, headers=conditional_headers)
            if resp.status_code == 304 and cached:
                return _CachedResponse(cached["html"], from_304=True)
            resp.raise_for_status()
            if cache and "html" in resp.headers.get("content-type", ""):
                cache.put(
                    url,
                    resp.headers.get("etag"),
                    resp.headers.get("last-modified"),
                    resp.text,
                )
            return resp
        except httpx.HTTPStatusError as exc:
            code = exc.response.status_code
            if code in RETRY_STATUS_CODES and attempt < MAX_RETRIES:
                retry_after = exc.response.headers.get("retry-after", "")
                wait = (
                    float(retry_after)
                    if retry_after.isdigit()
                    else BACKOFF_BASE * (2**attempt)
                )
                print(
                    f"  ↻  HTTP {code} — retrying in {wait:.0f}s  ({url})",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            if not (silent_404 and code in (404, 403, 401)):
                print(f"  ⚠  HTTP {code}: {url}", file=sys.stderr)
            return None
        except Exception as exc:
            if attempt < MAX_RETRIES:
                wait = BACKOFF_BASE * (2**attempt)
                print(
                    f"  ↻  {type(exc).__name__} — retrying in {wait:.0f}s  ({url})",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            print(f"  ⚠  {type(exc).__name__}: {url}", file=sys.stderr)
            return None
    return None


# ── URL utilities ────────────────────────────────────────────────────────────────
def origin(url: str) -> str:
    parsed = urlparse(url)
    return f"{parsed.scheme}://{parsed.netloc}"


def normalize(url: str) -> str:
    p = urlparse(url)
    path = p.path.rstrip("/") or "/"
    return p._replace(
        scheme=p.scheme.lower(),
        netloc=p.netloc.lower(),
        path=path,
        query="",
        fragment="",
    ).geturl()


def same_domain(url: str, root: str) -> bool:
    return urlparse(url).netloc.lower() == urlparse(root).netloc.lower()


def is_doc_url(url: str, ignore_changelog: bool = False) -> bool:
    path = urlparse(url).path.lower()
    blocked = list(IGNORE_PATH_FRAGMENTS)
    if ignore_changelog:
        blocked += ["changelog", "release-notes", "releases", "whats-new"]
    return not any(fragment in path for fragment in blocked)


def is_asset(url: str) -> bool:
    path = urlparse(url).path.lower()
    _, _, ext = path.rpartition(".")
    return f".{ext}" in ASSET_EXTENSIONS if ext else False


def passes_filters(url: str, include: List[str], exclude: List[str]) -> bool:
    url_lower = url.lower()
    if include and not any(term.lower() in url_lower for term in include):
        return False
    if any(term.lower() in url_lower for term in exclude):
        return False
    return True


def probe_urls(root: str, paths: List[str]) -> List[str]:
    candidates: List[str] = []
    seen: Set[str] = set()
    bases = [root.rstrip("/"), origin(root)]
    for base in bases:
        for path in paths:
            full = base + path
            if full not in seen:
                seen.add(full)
                candidates.append(full)
    return candidates


# ── robots.txt ──────────────────────────────────────────────────────────────────
def parse_robots_txt(client: httpx.Client, root: str) -> Dict[str, Any]:
    result: Dict[str, Any] = {"sitemaps": [], "crawl_delay": None}
    resp = fetch(client, origin(root) + "/robots.txt")
    if not resp:
        return result

    our_agent = "doc-ingester"
    in_relevant_section = False
    for raw_line in resp.text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip().lower()
        value = value.strip()
        if key == "sitemap":
            if value and value not in result["sitemaps"]:
                result["sitemaps"].append(value)
        elif key == "user-agent":
            in_relevant_section = value == "*" or our_agent in value.lower()
        elif key == "crawl-delay" and in_relevant_section:
            try:
                delay = float(value)
                current = result["crawl_delay"] or 0.0
                result["crawl_delay"] = max(current, delay)
            except ValueError:
                pass
    return result


# ── discovery: llms-full.txt ────────────────────────────────────────────────────
def try_llms_full(client: httpx.Client, root: str) -> Optional[str]:
    for url in probe_urls(root, ["/llms-full.txt"]):
        resp = fetch(client, url)
        if resp and "text" in resp.headers.get("content-type", ""):
            text = resp.text.strip()
            if len(text) > 500:
                print(f"  ✓ llms-full.txt found at {url}  ({len(text):,} chars)")
                return text
    return None


# ── discovery: llms.txt ─────────────────────────────────────────────────────────
def try_llms_txt(client: httpx.Client, root: str) -> List[str]:
    for url in probe_urls(root, ["/llms.txt"]):
        resp = fetch(client, url)
        if not resp:
            continue
        if "text" not in resp.headers.get("content-type", ""):
            continue
        urls: List[str] = []
        for line in resp.text.splitlines():
            for m in re.finditer(r"\[([^\]]*)\]\((https?://[^)]+)\)", line):
                urls.append(m.group(2).strip())
            if not urls or not re.search(r"\[.*\]\(", line):
                for m in re.finditer(r"https?://\S+", line):
                    candidate = m.group(0).rstrip(").,;")
                    if candidate not in urls:
                        urls.append(candidate)
        if urls:
            print(f"  ✓ llms.txt found at {url}  ({len(urls)} links)")
            return urls
    return []


# ── discovery: sitemap.xml ──────────────────────────────────────────────────────
def _parse_sitemap(
    client: httpx.Client,
    url: str,
    root: str,
    visited: Optional[Set[str]] = None,
) -> List[str]:
    if visited is None:
        visited = set()
    if url in visited:
        return []
    visited.add(url)

    resp = fetch(client, url)
    if not resp:
        return []
    try:
        soup = BeautifulSoup(resp.text, "lxml-xml")
    except Exception:
        soup = BeautifulSoup(resp.text, "html.parser")

    found: List[str] = []
    for sitemap_tag in soup.find_all("sitemap"):
        loc = sitemap_tag.find("loc")
        if loc and loc.text:
            found.extend(_parse_sitemap(client, loc.text.strip(), root, visited))

    for url_tag in soup.find_all("url"):
        loc = url_tag.find("loc")
        if loc and loc.text:
            u = loc.text.strip()
            if same_domain(u, root):
                found.append(u)

    if not found:
        for loc in soup.find_all("loc"):
            u = loc.text.strip()
            if same_domain(u, root):
                found.append(u)
    return found


def try_sitemap(
    client: httpx.Client,
    root: str,
    extra_sitemaps: Optional[List[str]] = None,
) -> List[str]:
    candidates: List[str] = list(extra_sitemaps or [])
    for url in probe_urls(root, SITEMAP_PATHS):
        if url not in candidates:
            candidates.append(url)

    visited_sitemaps: Set[str] = set()
    for url in candidates:
        if url in visited_sitemaps:
            continue
        visited_sitemaps.add(url)
        urls = _parse_sitemap(client, url, root)
        if urls:
            print(f"  ✓ sitemap found at {url}  ({len(urls)} URLs)")
            return urls
    return []


# ── discovery: BFS crawl ────────────────────────────────────────────────────────
def crawl(
    client: httpx.Client,
    root: str,
    max_pages: int,
    delay: float,
    ignore_changelog: bool,
    include: List[str],
    exclude: List[str],
    cache: Optional[Cache] = None,
) -> List[str]:
    print("  ↩  No llms.txt or sitemap — falling back to BFS crawl")
    queue: deque = deque([root])
    seen: Set[str] = {normalize(root)}
    found: List[str] = []

    while queue and len(found) < max_pages:
        url = queue.popleft()
        resp = fetch(client, url, cache)
        if not resp:
            continue
        if "html" not in resp.headers.get("content-type", ""):
            continue
        found.append(url)
        if len(found) % 20 == 0:
            print(f"    … {len(found)} pages crawled")

        soup = BeautifulSoup(resp.text, "lxml")
        for tag in soup.find_all("a", href=True):
            href = tag["href"].strip()
            if not href or href.startswith(("#", "mailto:", "tel:", "javascript:")):
                continue
            absolute = normalize(urljoin(url, href))
            if (
                absolute not in seen
                and same_domain(absolute, root)
                and not is_asset(absolute)
                and is_doc_url(absolute, ignore_changelog)
                and passes_filters(absolute, include, exclude)
            ):
                seen.add(absolute)
                queue.append(absolute)
        time.sleep(delay)
    return found


# ── URL discovery orchestrator ──────────────────────────────────────────────────
def discover(
    client: httpx.Client,
    root: str,
    max_pages: int,
    delay: float,
    ignore_changelog: bool,
    include: List[str],
    exclude: List[str],
    cache: Optional[Cache] = None,
) -> Tuple[str, Any]:
    print("\n── Discovery ──────────────────────────────────────────────────────────")
    print("  … checking robots.txt")
    robots = parse_robots_txt(client, root)
    if robots["sitemaps"]:
        print(f"  ✓ robots.txt: {len(robots['sitemaps'])} sitemap(s) referenced")
    if robots["crawl_delay"] is not None:
        effective = max(delay, robots["crawl_delay"])
        if effective > delay:
            print(
                f"  ✓ robots.txt: crawl-delay {robots['crawl_delay']}s — using {effective}s"
            )
            delay = effective

    full_text = try_llms_full(client, root)
    if full_text:
        return "llms-full", full_text

    llms_urls = try_llms_txt(client, root)
    if llms_urls:
        filtered = [
            u
            for u in llms_urls
            if same_domain(u, root)
            and is_doc_url(u, ignore_changelog)
            and not is_asset(u)
            and passes_filters(u, include, exclude)
        ]
        return "llms", filtered

    sitemap_urls = try_sitemap(client, root, robots["sitemaps"])
    if sitemap_urls:
        filtered = [
            u
            for u in sitemap_urls
            if is_doc_url(u, ignore_changelog)
            and not is_asset(u)
            and passes_filters(u, include, exclude)
        ]
        return "sitemap", filtered

    crawled = crawl(
        client, root, max_pages, delay, ignore_changelog, include, exclude, cache
    )
    return "crawl", crawled


# ── canonical URL support ────────────────────────────────────────────────────────
def get_canonical(soup: BeautifulSoup, url: str) -> str:
    tag = soup.find("link", rel=lambda r: r and "canonical" in r)
    if tag and tag.get("href"):
        canonical = normalize(urljoin(url, tag["href"]))
        if same_domain(canonical, url):
            return canonical
    return url


# ── JS detection ────────────────────────────────────────────────────────────────
def is_js_heavy(html: str, extracted_text: Optional[str]) -> bool:
    if extracted_text and len(extracted_text.strip()) > 300:
        return False
    soup = BeautifulSoup(html, "lxml")
    scripts = soup.find_all("script")
    body = soup.find("body")
    body_text = body.get_text(strip=True) if body else ""
    return len(body_text) < 300 and len(scripts) > 5


# ── Playwright fallback ──────────────────────────────────────────────────────────
def fetch_with_playwright(url: str) -> Optional[str]:
    if not PLAYWRIGHT_AVAILABLE:
        return None
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True)
            page = browser.new_page(user_agent=USER_AGENT)
            page.goto(url, wait_until="networkidle", timeout=30_000)
            html = page.content()
            browser.close()
            return html
    except Exception as exc:
        print(f"  ⚠  Playwright error for {url}: {exc}", file=sys.stderr)
        return None


async def fetch_page_with_browser(browser: Any, url: str) -> Optional[str]:
    try:
        ctx = await browser.new_context(user_agent=USER_AGENT)
        try:
            page = await ctx.new_page()
            await page.goto(url, wait_until="networkidle", timeout=30_000)
            html = await page.content()
            return html
        finally:
            await ctx.close()
    except Exception as exc:
        print(f"  ⚠  Playwright error for {url}: {exc}", file=sys.stderr)
        return None


# ── content extraction ──────────────────────────────────────────────────────────
def extract_title(soup: BeautifulSoup, url: str) -> str:
    for selector in ("h1", "title"):
        tag = soup.find(selector)
        if tag:
            text = tag.get_text(strip=True)
            if text:
                return re.split(r"\s*[|—–]\s*", text)[0].strip()
    path = urlparse(url).path.strip("/")
    if path:
        return path.replace("/", " › ").replace("-", " ").replace("_", " ").title()
    return url


def _extract_breadcrumbs(soup: BeautifulSoup) -> List[str]:
    for selector in BREADCRUMB_SELECTORS:
        el = soup.select_one(selector)
        if not el:
            continue
        items: List[str] = []
        for child in el.find_all(["a", "li", "span"]):
            text = child.get_text(strip=True)
            if text and not re.fullmatch(r"[›/>|·\-–—]+", text):
                items.append(text)
        seen: Set[str] = set()
        unique_items: List[str] = []
        for item in items:
            if item not in seen:
                seen.add(item)
                unique_items.append(item)
        if len(unique_items) >= 2:
            return unique_items
    return []


def _extract_asset_refs(soup: BeautifulSoup) -> List[Dict[str, str]]:
    assets: List[Dict[str, str]] = []
    for img in soup.find_all("img"):
        alt = img.get("alt", "").strip()
        src = img.get("src", "").strip()
        if not alt and not src:
            continue
        caption = ""
        fig = img.find_parent("figure")
        if fig:
            cap = fig.find("figcaption")
            if cap:
                caption = cap.get_text(strip=True)
        if alt or caption:
            assets.append({"alt": alt, "src": src, "caption": caption})
    return assets


def _extract_internal_links(
    soup: BeautifulSoup, url: str, root: str
) -> List[Dict[str, str]]:
    links: List[Dict[str, str]] = []
    seen: Set[str] = set()
    current_norm = normalize(url)
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        if not href or href.startswith(("#", "mailto:", "tel:", "javascript:")):
            continue
        absolute = normalize(urljoin(url, href))
        if (
            same_domain(absolute, root)
            and absolute != current_norm
            and absolute not in seen
            and not is_asset(absolute)
        ):
            seen.add(absolute)
            anchor_text = a.get_text(strip=True)
            links.append({"target": absolute, "anchor": anchor_text})
    return links


def _strip_chrome(soup: BeautifulSoup) -> None:
    for selector in STRIP_SELECTORS:
        for tag in soup.select(selector):
            tag.decompose()


def _find_content_container(soup: BeautifulSoup) -> Any:
    for selector in MAIN_CONTENT_SELECTORS:
        el = soup.select_one(selector)
        if el:
            return el
    return soup


def _with_trafilatura(html: str, url: str) -> Optional[str]:
    result = trafilatura.extract(
        html,
        url=url,
        include_tables=True,
        include_links=False,
        include_images=False,
        include_formatting=True,
        output_format="markdown",
        favor_recall=True,
    )
    return result or None


def _with_bs4(html: str, url: str) -> str:
    soup = BeautifulSoup(html, "lxml")
    _strip_chrome(soup)
    container = _find_content_container(soup)
    return _to_md(
        str(container),
        heading_style="ATX",
        bullets="-",
        strip=["script", "style", "img", "svg", "button", "form", "input"],
    )


def clean_markdown(text: str) -> str:
    text = re.sub(r"\n{3,}", "\n", text)
    lines = [line.rstrip() for line in text.splitlines()]
    return "\n".join(lines).strip()


def _content_hash(content: str) -> str:
    normalized = re.sub(r"\s+", " ", content.strip())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def extract_page(
    client: httpx.Client,
    url: str,
    delay: float,
    use_browser: bool = False,
    cache: Optional[Cache] = None,
    root: str = "",
    prev_page: Optional[Dict] = None,
) -> Optional[Dict[str, Any]]:
    resp = fetch(client, url, cache)
    if not resp:
        return None
    if getattr(resp, "from_304", False) and prev_page is not None:
        return prev_page
    if "html" not in resp.headers.get("content-type", ""):
        return None

    html = resp.text
    effective_root = root or origin(url)
    soup = BeautifulSoup(html, "lxml")
    title = extract_title(soup, url)
    canonical_url = get_canonical(soup, url)
    breadcrumbs = _extract_breadcrumbs(soup)
    asset_refs = _extract_asset_refs(soup)
    internal_links = _extract_internal_links(soup, url, effective_root)

    content = _with_trafilatura(html, url)
    js_heavy = False

    if is_js_heavy(html, content):
        js_heavy = True
        if use_browser:
            rendered = fetch_with_playwright(url)
            if rendered:
                html = rendered
                soup = BeautifulSoup(html, "lxml")
                title = extract_title(soup, url)
                canonical_url = get_canonical(soup, url)
                breadcrumbs = _extract_breadcrumbs(soup)
                asset_refs = _extract_asset_refs(soup)
                internal_links = _extract_internal_links(soup, url, effective_root)
                content = _with_trafilatura(html, url)
                js_heavy = False
            else:
                print(
                    f"  ⚡  JS-heavy — try --browser for better results: {url}",
                    file=sys.stderr,
                )

    if not content or len(content.strip()) < 80:
        content = _with_bs4(html, url)
    if not content or len(content.strip()) < 40:
        return None

    content = clean_markdown(content)
    time.sleep(delay)

    return {
        "title": title,
        "url": url,
        "canonical_url": canonical_url,
        "content": content,
        "word_count": len(content.split()),
        "content_hash": _content_hash(content),
        "breadcrumbs": breadcrumbs,
        "js_heavy": js_heavy,
        "asset_refs": asset_refs,
        "internal_links": internal_links,
    }


# ── output writers ──────────────────────────────────────────────────────────────
def _page_frontmatter(page: Dict[str, Any]) -> str:
    lines = ["---"]
    title = page["title"].replace('"', '\\"')
    lines.append(f'title: "{title}"')
    lines.append(f"url: {page['url']}")
    if page.get("canonical_url") and page["canonical_url"] != page["url"]:
        lines.append(f"canonical_url: {page['canonical_url']}")
    lines.append(f"word_count: {page['word_count']}")
    lines.append(f"content_hash: {page['content_hash']}")
    lines.append("---")
    return "\n".join(lines)


def _page_section(page: Dict[str, Any]) -> str:
    frontmatter = _page_frontmatter(page)
    return f"{frontmatter}\n{page['content']}"


def _build_toc(pages: List[Dict]) -> str:
    lines = ["## Documentation Index\n"]
    for page in pages:
        title = page["title"]
        anchor = re.sub(r"[^\w\s-]", "", title.lower()).strip()
        anchor = re.sub(r"\s+", "-", anchor)
        lines.append(f"- [{title}](#{anchor})")
    return "\n".join(lines)


def write_combined_md(pages: List[Dict], output_dir: Path) -> None:
    toc = _build_toc(pages)
    header = (
        f"# Documentation Bundle\n"
        f"Generated: {datetime.now(timezone.utc).isoformat()}\n"
        f"{toc}\n"
    )
    body = PAGE_DIVIDER.join(_page_section(p) for p in pages)
    path = output_dir / "combined.md"
    path.write_text(header + PAGE_DIVIDER + body, encoding="utf-8")
    size_kb = path.stat().st_size / 1024
    print(f"  ✓ combined.md        {len(pages)} pages  /  {size_kb:,.0f} KB")


def _strip_nav_from_content(content: str) -> str:
    for pattern in _NAV_PATTERNS:
        content = pattern.sub("", content)
    content = re.sub(r"\n{3,}", "\n", content)
    return content.strip()


def write_llm_bundle(pages: List[Dict], output_dir: Path) -> None:
    sections: List[str] = []
    for page in pages:
        content = _strip_nav_from_content(page["content"])
        if not content:
            continue
        header = f"# {page['title']}\n> {page['url']}"
        sections.append(f"{header}\n{content}")

    bundle_body = "\n---\n".join(sections)
    bundle_body = re.sub(r"\n{3,}", "\n", bundle_body).strip()
    header = (
        f"# LLM Documentation Bundle\n"
        f"Generated: {datetime.now(timezone.utc).isoformat()}\n"
        f"Pages: {len(sections)}\n"
        f"---\n"
    )
    path = output_dir / "llm-bundle.md"
    path.write_text(header + bundle_body, encoding="utf-8")
    size_kb = path.stat().st_size / 1024
    print(
        f"  ✓ llm-bundle.md      {len(sections)} pages  /  {size_kb:,.0f} KB  (AI-optimized)"
    )


def write_split_pages(pages: List[Dict], output_dir: Path) -> None:
    pages_dir = output_dir / "pages"
    pages_dir.mkdir(exist_ok=True)
    for page in pages:
        path_part = urlparse(page["url"]).path.strip("/").replace("/", "__") or "index"
        path_part = re.sub(r"[^\w\-.]", "_", path_part)
        filepath = pages_dir / f"{path_part}.md"
        filepath.write_text(_page_section(page), encoding="utf-8")
    print(f"  ✓ pages/             {len(pages)} individual files")


def write_urls_txt(urls: List[str], output_dir: Path) -> None:
    path = output_dir / "urls.txt"
    path.write_text("\n".join(urls) + "\n", encoding="utf-8")
    print(f"  ✓ urls.txt           {len(urls)} URLs")


def write_metadata(
    pages: List[Dict],
    root: str,
    strategy: str,
    output_dir: Path,
) -> None:
    total_words = sum(p["word_count"] for p in pages)
    metadata = {
        "source": root,
        "strategy": strategy,
        "pages": len(pages),
        "total_words": total_words,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ingester_version": VERSION,
        "documents": [
            {
                "title": p["title"],
                "url": p["url"],
                "canonical_url": p.get("canonical_url", p["url"]),
                "word_count": p["word_count"],
                "content_hash": p.get("content_hash", ""),
                **({"asset_refs": p["asset_refs"]} if p.get("asset_refs") else {}),
            }
            for p in pages
        ],
    }
    path = output_dir / "metadata.json"
    path.write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"  ✓ metadata.json      ~{total_words:,} total words")


def _infer_topics(pages: List[Dict], root: str) -> List[str]:
    root_path = urlparse(root).path.strip("/")
    topics: Set[str] = set()
    for page in pages:
        group = _infer_group(page, root_path)
        if group.lower() not in ("overview",):
            topics.add(group.lower().replace(" ", "_").replace("-", "_"))
    return sorted(topics)[:20]


def write_manifest(
    pages: List[Dict],
    root: str,
    strategy: str,
    output_dir: Path,
    page_count: Optional[int] = None,
    word_count: Optional[int] = None,
    snapshot: Optional[str] = None,
    doc_version: Optional[str] = None,
) -> None:
    netloc = urlparse(root).netloc
    domain = netloc.removeprefix("www.").removeprefix("docs.")
    name = domain.split(".")[0].title()
    pages_n = page_count if page_count is not None else len(pages)
    words_n = (
        word_count if word_count is not None else sum(p["word_count"] for p in pages)
    )
    topics = _infer_topics(pages, root) if pages else []
    manifest: Dict[str, Any] = {
        "name": name,
        "source": root,
        "strategy": strategy,
        "pages": pages_n,
        "words": words_n,
        "topics": topics,
        "crawl_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ingester_version": VERSION,
    }
    if snapshot:
        manifest["snapshot"] = snapshot
    if doc_version:
        manifest["doc_version"] = doc_version

    path = output_dir / "manifest.json"
    path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    topics_str = ", ".join(topics[:5]) + (
        f" +{len(topics) - 5}" if len(topics) > 5 else ""
    )
    print(f"  ✓ manifest.json      {name}  /  {pages_n} pages  /  ~{words_n:,} words")
    if topics:
        print(f"    topics: {topics_str}")


def build_search_index(pages: List[Dict]) -> Dict[str, List[str]]:
    index: Dict[str, List[str]] = defaultdict(list)
    for page in pages:
        title = page["title"]
        headings = re.findall(r"^#{1,3}\s+(.+)", page["content"], re.MULTILINE)
        body_paras = [
            p.strip()
            for p in re.split(r"\n+", page["content"])
            if p.strip()
            and not p.strip().startswith("#")
            and not p.strip().startswith("```")
            and not p.strip().startswith("|")
            and len(p.strip()) > 20
        ]
        intro_text = " ".join(body_paras[:3])
        table_header_tokens: List[str] = []
        for para in re.split(r"\n+", page["content"]):
            lines = para.strip().splitlines()
            if (
                len(lines) >= 2
                and lines[0].startswith("|")
                and re.match(r"^\|[\s\-:|]+\|", lines[1])
            ):
                header_cells = [c.strip() for c in lines[0].split("|") if c.strip()]
                table_header_tokens.extend(header_cells)

        words_source = (
            title
            + " "
            + " ".join(headings)
            + " "
            + intro_text
            + " "
            + " ".join(table_header_tokens)
        )
        tokens = re.findall(r"\b[a-zA-Z][a-zA-Z0-9_.-]{1,}\b", words_source)
        seen_for_page: Set[str] = set()
        for token in tokens:
            w = token.lower().rstrip(".-_")
            if w not in _SEARCH_STOPWORDS and len(w) >= 3:
                if w not in seen_for_page:
                    seen_for_page.add(w)
                    if title not in index[w]:
                        index[w].append(title)
    return dict(sorted(index.items()))


def write_search_index(pages: List[Dict], output_dir: Path) -> None:
    index = build_search_index(pages)
    path = output_dir / "search-index.json"
    path.write_text(json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8")
    size_kb = path.stat().st_size / 1024
    print(f"  ✓ search-index.json  {len(index):,} keywords  /  {size_kb:,.0f} KB")


def _nearest_heading(content: str, match_start: int) -> str:
    preceding = [
        text.strip()
        for pos, text in (
            (m.start(), m.group(1))
            for m in re.finditer(r"^#{1,3}\s+(.+)", content, re.MULTILINE)
        )
        if pos < match_start
    ]
    return preceding[-1] if preceding else ""


def extract_code_examples(pages: List[Dict], output_dir: Path) -> None:
    examples_dir = output_dir / "examples"
    examples_dir.mkdir(exist_ok=True)
    by_lang: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    section_langs: Dict[str, Set[str]] = defaultdict(set)

    for page in pages:
        for match in _CODE_FENCE.finditer(page["content"]):
            lang = (match.group(1) or "text").lower().strip() or "text"
            code = match.group(2).strip()
            if len(code) < 15:
                continue
            section = _nearest_heading(page["content"], match.start())
            by_lang[lang].append(
                {
                    "page_title": page["title"],
                    "source_url": page["url"],
                    "section": section,
                    "code": code,
                }
            )
            if section:
                section_langs[section].add(lang)

    total = 0
    for lang, snippets in sorted(by_lang.items()):
        lang_safe = re.sub(r"[^\w\-]", "_", lang)
        lang_file = examples_dir / f"{lang_safe}.json"
        lang_file.write_text(
            json.dumps(snippets, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        total += len(snippets)

    summary = {lang: len(snips) for lang, snips in sorted(by_lang.items())}
    (examples_dir / "index.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    examples_index = {
        section: sorted(langs) for section, langs in sorted(section_langs.items())
    }
    (examples_dir / "examples-index.json").write_text(
        json.dumps(examples_index, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    if by_lang:
        top_langs = sorted(by_lang, key=lambda k: len(by_lang[k]), reverse=True)
        langs_str = ", ".join(top_langs[:6])
        if len(by_lang) > 6:
            langs_str += f", +{len(by_lang) - 6} more"
        print(
            f"  ✓ examples/          {total} snippets  /  {len(by_lang)} languages  ({langs_str})"
        )
        print(f"    examples-index.json: {len(examples_index)} sections")
    else:
        print(f"  ✓ examples/          0 snippets found")


def write_links_graph(pages: List[Dict], output_dir: Path) -> None:
    ingested_paths: Set[str] = {urlparse(p["url"]).path for p in pages}
    graph: Dict[str, List[Dict[str, str]]] = {}
    for page in pages:
        links = page.get("internal_links", [])
        if not links:
            continue
        src_path = urlparse(page["url"]).path
        dst_entries: List[Dict[str, str]] = []
        seen: Set[str] = set()
        for link in links:
            if isinstance(link, str):
                target_url, anchor = link, ""
            else:
                target_url = link.get("target", "")
                anchor = link.get("anchor", "")
            dst_path = urlparse(target_url).path
            if (
                dst_path in ingested_paths
                and dst_path != src_path
                and dst_path not in seen
            ):
                seen.add(dst_path)
                entry: Dict[str, str] = {"target": dst_path}
                if anchor:
                    entry["anchor"] = anchor
                dst_entries.append(entry)
        if dst_entries:
            graph[src_path] = dst_entries

    path = output_dir / "links.json"
    path.write_text(json.dumps(graph, indent=2, ensure_ascii=False), encoding="utf-8")
    edge_count = sum(len(v) for v in graph.values())
    print(
        f"  ✓ links.json         {len(graph)} pages  /  {edge_count} edges  (with anchor text)"
    )


def write_docs_map(pages: List[Dict], root: str, output_dir: Path) -> None:
    domain = urlparse(root).netloc
    root_path = urlparse(root).path.strip("/")
    groups: Dict[str, List[str]] = defaultdict(list)
    for page in pages:
        group = _infer_group(page, root_path)
        groups[group].append(page["title"])

    lines = [f"# Docs Map — {domain}\n"]
    for group in sorted(groups):
        lines.append(f"\n## {group}")
        for title in groups[group]:
            lines.append(f"- {title}")
    path = output_dir / "docs-map.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  ✓ docs-map.md        {len(groups)} sections")


_VERSION_SEGMENT = re.compile(
    r"^(v\d[\w.]*|latest|stable|current|master|main|next|\d+[.\d]*)$", re.I
)


def _first_content_segment(parts: List[str]) -> Optional[str]:
    for part in parts:
        if part and not _VERSION_SEGMENT.match(part):
            return part
    return parts[0] if parts else None


def _infer_group(page: Dict[str, Any], root_path: str) -> str:
    crumbs = page.get("breadcrumbs", [])
    if len(crumbs) >= 2:
        candidate = crumbs[1].strip()
        if candidate and len(candidate) < 60:
            return candidate

    parsed = urlparse(page["url"])
    path = parsed.path.strip("/")
    if root_path and path.startswith(root_path):
        path = path[len(root_path) :].strip("/")
    parts = [p for p in path.split("/") if p]
    segment = _first_content_segment(parts)
    if segment:
        return segment.replace("-", " ").replace("_", " ").title()
    return "Overview"


def write_quality_report(
    pages: List[Dict],
    discovered: int,
    skipped: int,
    canonical_dedups: int,
    strategy: str,
    root: str,
    output_dir: Path,
    incremental_stats: Optional[Dict] = None,
) -> None:
    extracted = len(pages)
    total_words = sum(p["word_count"] for p in pages)
    js_heavy = sum(1 for p in pages if p.get("js_heavy", False))
    avg_words = total_words / extracted if extracted else 0
    success_rate = (extracted / discovered * 100) if discovered else 0
    total_asset_refs = sum(len(p.get("asset_refs", [])) for p in pages)
    width = 28
    lines = [
        f"doc_ingester v{VERSION} — Quality Report",
        "=" * 50,
        "",
        f"{'Source':<{width}}: {root}",
        f"{'Strategy':<{width}}: {strategy}",
        f"{'Run date':<{width}}: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
        "",
        "Pages",
        "─" * 30,
        f"  {'Discovered':<{width - 2}}: {discovered:>6}",
        f"  {'Extracted':<{width - 2}}: {extracted:>6}",
        f"  {'Skipped':<{width - 2}}: {skipped:>6}",
        f"  {'JS-heavy':<{width - 2}}: {js_heavy:>6}",
        f"  {'Canonical dedups removed':<{width - 2}}: {canonical_dedups:>6}",
        "",
        "Content",
        "─" * 30,
        f"  {'Total words':<{width - 2}}: {total_words:>10,}",
        f"  {'Average words/page':<{width - 2}}: {avg_words:>10,.0f}",
        f"  {'Image/asset references':<{width - 2}}: {total_asset_refs:>6}",
        "",
        f"{'Extraction success rate':<{width}}: {success_rate:.1f}%",
    ]
    if incremental_stats:
        lines += [
            "",
            "Incremental (--update)",
            "─" * 30,
            f"  {'Unchanged':<{width - 2}}: {incremental_stats.get('unchanged', 0):>6}",
            f"  {'Changed':<{width - 2}}: {incremental_stats.get('changed', 0):>6}",
            f"  {'New':<{width - 2}}: {incremental_stats.get('new', 0):>6}",
            f"  {'Removed':<{width - 2}}: {incremental_stats.get('removed', 0):>6}",
        ]
    report_text = "\n".join(lines) + "\n"
    path = output_dir / "report.txt"
    path.write_text(report_text, encoding="utf-8")
    print(
        f"  ✓ report.txt         {extracted} extracted / {discovered} discovered / {success_rate:.1f}% success"
    )


def write_knowledge_catalog(base_output_dir: Path) -> None:
    pack_candidates: Dict[str, List[Tuple[str, Path]]] = defaultdict(list)
    for manifest_path in sorted(base_output_dir.rglob("manifest.json")):
        relative = manifest_path.relative_to(base_output_dir)
        parts = relative.parts
        if ".cache" in parts or len(parts) > 3:
            continue
        pack_dir_name = parts[0]
        if len(parts) == 2:
            sort_key = "zzz_direct"
        elif len(parts) == 3:
            sort_key = parts[1]
        else:
            continue
        pack_candidates[pack_dir_name].append((sort_key, manifest_path))

    if not pack_candidates:
        return

    catalog: Dict[str, Any] = {}
    for pack_dir_name, candidates in pack_candidates.items():
        _, best_path = max(candidates, key=lambda x: x[0])
        try:
            manifest = json.loads(best_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        name = manifest.get("name", "").lower() or pack_dir_name.lower()
        pack_dir = best_path.parent.relative_to(base_output_dir)
        pack_path = str(pack_dir) if str(pack_dir) != "." else name
        catalog[name] = {
            "source": manifest.get("source", ""),
            "pages": manifest.get("pages", 0),
            "words": manifest.get("words", 0),
            "topics": manifest.get("topics", []),
            "last_updated": manifest.get("generated_at", ""),
            "crawl_date": manifest.get("crawl_date", ""),
            "snapshot": manifest.get("snapshot"),
            "path": pack_path,
        }
    if not catalog:
        return

    catalog_path = base_output_dir / "catalog.json"
    catalog_path.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    names_preview = ", ".join(sorted(catalog.keys())[:5])
    if len(catalog) > 5:
        names_preview += f"  +{len(catalog) - 5} more"
    print(f"  ✓ catalog.json       {len(catalog)} packs  ({names_preview})")


def write_zip(output_dir: Path) -> None:
    zip_path = output_dir.parent / f"{output_dir.name}.zip"
    try:
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for item in sorted(output_dir.rglob("*")):
                if ".cache" in item.parts:
                    continue
                if item.is_file():
                    arcname = item.relative_to(output_dir).as_posix()
                    zf.write(item, arcname)
        size_kb = zip_path.stat().st_size / 1024
        print(f"  ✓ {zip_path.name:<20} {size_kb:,.0f} KB")
    except PermissionError:
        zip_path = output_dir / "archive.zip"
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for item in sorted(output_dir.rglob("*")):
                if ".cache" in item.parts or item == zip_path:
                    continue
                if item.is_file():
                    zf.write(item, item.relative_to(output_dir).as_posix())
        size_kb = zip_path.stat().st_size / 1024
        print(f"  ✓ archive.zip        {size_kb:,.0f} KB  (written inside output dir)")


# ── llms-full.txt shortcut ──────────────────────────────────────────────────────
def handle_llms_full(raw_text: str, root: str, output_dir: Path) -> None:
    content = clean_markdown(raw_text)
    path = output_dir / "combined.md"
    header = (
        f"# Documentation Bundle\n"
        f"Source: {root}\n"
        f"Generated: {datetime.now(timezone.utc).isoformat()}\n"
        f"\n{PAGE_DIVIDER}"
    )
    path.write_text(header + content, encoding="utf-8")
    page_count = len(re.findall(r"^#{1,2} ", content, re.MULTILINE)) or 1
    word_count = len(content.split())
    size_kb = path.stat().st_size / 1024
    print(f"  ✓ combined.md        {size_kb:,.0f} KB  /  ~{word_count:,} words")

    bundle_content = content
    for pattern in _NAV_PATTERNS:
        bundle_content = pattern.sub("", bundle_content)
    bundle_content = re.sub(r"\n{3,}", "\n", bundle_content).strip()
    bundle_path = output_dir / "llm-bundle.md"
    bundle_path.write_text(
        f"# LLM Documentation Bundle\n"
        f"Source: {root}\n"
        f"Generated: {datetime.now(timezone.utc).isoformat()}\n"
        f"---\n"
        f"{bundle_content}",
        encoding="utf-8",
    )
    bundle_kb = bundle_path.stat().st_size / 1024
    print(f"  ✓ llm-bundle.md      {bundle_kb:,.0f} KB  (AI-optimized)")

    (output_dir / "urls.txt").write_text(root + "\n", encoding="utf-8")
    print(f"  ✓ urls.txt           (llms-full.txt source — no URL list)")

    metadata = {
        "source": root,
        "strategy": "llms-full",
        "pages": page_count,
        "total_words": word_count,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ingester_version": VERSION,
        "documents": [],
    }
    (output_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"  ✓ metadata.json      ~{word_count:,} words  /  ~{page_count} sections")
    write_manifest([], root, "llms-full", output_dir, page_count, word_count)


# ── diff / compare mode ─────────────────────────────────────────────────────────
def compare_outputs(old_dir: Path, new_dir: Path) -> None:
    def load_docs(d: Path) -> Dict[str, Dict]:
        meta_path = d / "metadata.json"
        if not meta_path.exists():
            sys.exit(f"❌  No metadata.json found in: {d}")
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            sys.exit(f"❌  Could not parse metadata.json in {d}: {exc}")
        return {doc["url"]: doc for doc in meta.get("documents", [])}

    old_docs = load_docs(old_dir)
    new_docs = load_docs(new_dir)
    old_urls = set(old_docs)
    new_urls = set(new_docs)

    added = sorted(new_urls - old_urls)
    removed = sorted(old_urls - new_urls)
    changed = []
    for url in sorted(old_urls & new_urls):
        old_hash = old_docs[url].get("content_hash", "")
        new_hash = new_docs[url].get("content_hash", "")
        if old_hash and new_hash:
            if old_hash != new_hash:
                changed.append(url)
        else:
            if old_docs[url]["word_count"] != new_docs[url]["word_count"]:
                changed.append(url)

    unchanged = len(old_urls & new_urls) - len(changed)
    hash_mode = any(d.get("content_hash") for d in old_docs.values())

    print(f"\n── Diff: {old_dir}  →  {new_dir}")
    print(f"         Before: {len(old_docs)} pages  |  After: {len(new_docs)} pages")
    print(
        f"         Change detection: {'content hash' if hash_mode else 'word count (legacy)'}\n"
    )

    if added:
        print(f"  ✅  {len(added)} new page(s):")
        for url in added:
            print(f"      + {url}")
    if removed:
        print(f"\n🗑   {len(removed)} removed page(s):")
        for url in removed:
            print(f"      - {url}")
    if changed:
        print(f"\n✏   {len(changed)} changed page(s):")
        for url in changed:
            old_wc = old_docs[url]["word_count"]
            new_wc = new_docs[url]["word_count"]
            delta = new_wc - old_wc
            sign = "+" if delta >= 0 else ""
            title = new_docs[url].get("title", url)
            hash_note = " [hash changed]" if hash_mode else f" ({sign}{delta:,} words)"
            print(f"      ~ {title}{hash_note}")
            print(f"        {url}")
    if unchanged:
        print(f"\n✓   {unchanged} page(s) unchanged")
    if not added and not removed and not changed:
        print("  ✓ No changes detected between the two runs.")
    print()


# ── incremental run helpers ─────────────────────────────────────────────────────
def load_previous_metadata(output_dir: Path) -> Dict[str, Dict]:
    meta_path = output_dir / "metadata.json"
    if not meta_path.exists():
        return {}
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        return {doc["url"]: doc for doc in meta.get("documents", [])}
    except Exception:
        return {}


def _compute_incremental_stats(
    pages: List[Dict],
    prev_metadata: Dict[str, Dict],
    all_discovered_urls: List[str],
) -> Dict[str, Any]:
    prev_urls = set(prev_metadata.keys())
    current_urls = {p["url"] for p in pages}
    new_pages: List[Dict] = []
    changed_pages: List[Dict] = []
    unchanged_pages: List[Dict] = []
    for page in pages:
        url = page["url"]
        if url not in prev_urls:
            new_pages.append(page)
        else:
            prev_hash = prev_metadata[url].get("content_hash", "")
            curr_hash = page.get("content_hash", "")
            if prev_hash and curr_hash and prev_hash == curr_hash:
                unchanged_pages.append(page)
            else:
                changed_pages.append(page)
    removed_urls = sorted(prev_urls - current_urls)
    return {
        "new": len(new_pages),
        "changed": len(changed_pages),
        "unchanged": len(unchanged_pages),
        "removed": len(removed_urls),
        "new_pages": new_pages,
        "changed_pages": changed_pages,
        "removed_urls": removed_urls,
    }


def _print_incremental_summary(stats: Dict[str, Any]) -> None:
    print(f"\n── Incremental Summary {'─' * 44}")
    print(f"  New       : {stats['new']:>4}")
    print(f"  Changed   : {stats['changed']:>4}")
    print(f"  Unchanged : {stats['unchanged']:>4}")
    print(f"  Removed   : {stats['removed']:>4}")
    if stats["changed_pages"]:
        print("\nChanged pages:")
        for p in stats["changed_pages"]:
            print(f"    ✏  {p['title']}")
            print(f"       {p['url']}")
    if stats["removed_urls"]:
        print("\nRemoved pages:")
        for url in stats["removed_urls"]:
            print(f"    🗑  {url}")


# ── snapshot support ────────────────────────────────────────────────────────────
def resolve_snapshot_dir(base_output_dir: Path) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y-%m")
    snapshot_dir = base_output_dir / stamp
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    return snapshot_dir


def update_latest_symlink(base_output_dir: Path, snapshot_dir: Path) -> None:
    latest_path = base_output_dir / "latest"
    snap_name = snapshot_dir.name
    if os.name == "nt":
        pointer = base_output_dir / "_latest.txt"
        pointer.write_text(snap_name + "\n", encoding="utf-8")
        print(f"  ✓ _latest.txt        → {snap_name}  (Windows: symlink skipped)")
        return

    if latest_path.is_symlink():
        latest_path.unlink()
    elif latest_path.exists():
        latest_path.rename(base_output_dir / f"latest_backup_{int(time.time())}")

    try:
        latest_path.symlink_to(snap_name)
        print(f"  ✓ latest/            → {snap_name}")
    except OSError as exc:
        pointer = base_output_dir / "_latest.txt"
        pointer.write_text(snap_name + "\n", encoding="utf-8")
        print(f"  ✓ _latest.txt        → {snap_name}  ({exc})")


# ── crawl resume support ────────────────────────────────────────────────────────
class ProgressTracker:
    def __init__(self, output_dir: Path) -> None:
        self._path = output_dir / "progress.json"
        self._lock: Optional[asyncio.Lock] = None
        self._done: Set[str] = set()

    def _ensure_lock(self) -> asyncio.Lock:
        if self._lock is None:
            self._lock = asyncio.Lock()
        return self._lock

    def load(self) -> Set[str]:
        if self._path.exists():
            try:
                data = json.loads(self._path.read_text(encoding="utf-8"))
                self._done = set(data.get("completed", []))
                return self._done
            except Exception:
                pass
        return set()

    async def mark_done(self, url: str) -> None:
        async with self._ensure_lock():
            self._done.add(url)
            try:
                self._path.write_text(
                    json.dumps({"completed": sorted(self._done)}, indent=2),
                    encoding="utf-8",
                )
            except Exception:
                pass

    def clear(self) -> None:
        try:
            if self._path.exists():
                self._path.unlink()
        except Exception:
            pass

    @property
    def count(self) -> int:
        return len(self._done)


# ── async fetch & extraction (replaces ThreadPoolExecutor) ─────────────────────
async def async_fetch(
    client: "httpx.AsyncClient",
    url: str,
    cache: Optional[Cache] = None,
    silent_404: bool = True,
) -> Optional[Any]:
    cached = cache.get(url) if cache else None
    conditional_headers: Dict[str, str] = {}
    if cached:
        if cached.get("etag"):
            conditional_headers["If-None-Match"] = cached["etag"]
        if cached.get("last_modified"):
            conditional_headers["If-Modified-Since"] = cached["last_modified"]

    for attempt in range(MAX_RETRIES + 1):
        try:
            resp = await client.get(url, headers=conditional_headers)
            if resp.status_code == 304 and cached:
                return _CachedResponse(cached["html"], from_304=True)
            resp.raise_for_status()
            if cache and "html" in resp.headers.get("content-type", ""):
                cache.put(
                    url,
                    resp.headers.get("etag"),
                    resp.headers.get("last-modified"),
                    resp.text,
                )
            return resp
        except httpx.HTTPStatusError as exc:
            code = exc.response.status_code
            if code in RETRY_STATUS_CODES and attempt < MAX_RETRIES:
                retry_after = exc.response.headers.get("retry-after", "")
                wait = (
                    float(retry_after)
                    if retry_after.isdigit()
                    else BACKOFF_BASE * (2**attempt)
                )
                print(
                    f"  ↻  HTTP {code} — retrying in {wait:.0f}s  ({url})",
                    file=sys.stderr,
                )
                await asyncio.sleep(wait)
                continue
            if not (silent_404 and code in (404, 403, 401)):
                print(f"  ⚠  HTTP {code}: {url}", file=sys.stderr)
            return None
        except Exception as exc:
            if attempt < MAX_RETRIES:
                wait = BACKOFF_BASE * (2**attempt)
                print(
                    f"  ↻  {type(exc).__name__} — retrying in {wait:.0f}s  ({url})",
                    file=sys.stderr,
                )
                await asyncio.sleep(wait)
                continue
            print(f"  ⚠  {type(exc).__name__}: {url}", file=sys.stderr)
            return None
    return None


async def async_extract_page(
    client: "httpx.AsyncClient",
    url: str,
    delay: float,
    browser: Optional[Any] = None,
    cache: Optional[Cache] = None,
    root: str = "",
    prev_page: Optional[Dict] = None,
) -> Optional[Dict[str, Any]]:
    resp = await async_fetch(client, url, cache)
    if not resp:
        return None
    if getattr(resp, "from_304", False) and prev_page is not None:
        return prev_page
    if "html" not in resp.headers.get("content-type", ""):
        return None

    html = resp.text
    effective_root = root or origin(url)
    loop = asyncio.get_running_loop()

    def _parse(html_input: str) -> Optional[Dict[str, Any]]:
        soup = BeautifulSoup(html_input, "lxml")
        title = extract_title(soup, url)
        canonical_url = get_canonical(soup, url)
        breadcrumbs = _extract_breadcrumbs(soup)
        asset_refs = _extract_asset_refs(soup)
        internal_links = _extract_internal_links(soup, url, effective_root)
        content = _with_trafilatura(html_input, url)
        js_heavy = is_js_heavy(html_input, content)
        if not content or len(content.strip()) < 80:
            content = _with_bs4(html_input, url)
        if not content or len(content.strip()) < 40:
            return None
        content = clean_markdown(content)
        return {
            "title": title,
            "url": url,
            "canonical_url": canonical_url,
            "content": content,
            "word_count": len(content.split()),
            "content_hash": _content_hash(content),
            "breadcrumbs": breadcrumbs,
            "js_heavy": js_heavy,
            "asset_refs": asset_refs,
            "internal_links": internal_links,
        }

    result = await loop.run_in_executor(None, _parse, html)
    if result and result.get("js_heavy"):
        if browser:
            rendered = await fetch_page_with_browser(browser, url)
            if rendered:
                result = await loop.run_in_executor(None, _parse, rendered)
                if result:
                    result["js_heavy"] = False
        else:
            print(
                f"  ⚡  JS-heavy — try --browser for better results: {url}",
                file=sys.stderr,
            )
    await asyncio.sleep(delay)
    return result


async def async_process_pages(
    urls: List[str],
    cache: Optional[Cache],
    args: argparse.Namespace,
    root: str,
    prev_metadata: Dict[str, Dict],
    total: int,
    progress: Optional["ProgressTracker"] = None,
) -> Tuple[List[Dict], int, int]:
    already_done: Set[str] = progress.load() if progress else set()
    if already_done:
        print(f"── Resuming: {len(already_done)} pages already completed — skipping\n")

    semaphore = asyncio.Semaphore(args.concurrency)
    print_lock = asyncio.Lock()
    results: Dict[int, Optional[Dict]] = {}
    width = len(str(total))

    _pw_handle: Any = None
    _browser: Any = None
    if args.browser and PLAYWRIGHT_AVAILABLE:
        _pw_handle = await async_playwright().start()
        _browser = await _pw_handle.chromium.launch(headless=True)
        print(f"  🌐  Playwright browser launched (shared across all workers)\n")

    try:
        async with httpx.AsyncClient(
            headers={
                "User-Agent": USER_AGENT,
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
            },
            timeout=args.timeout,
            follow_redirects=True,
        ) as client:

            async def _worker(idx: int, url: str) -> None:
                if already_done and url in already_done:
                    prev = prev_metadata.get(url)
                    if prev:
                        results[idx] = prev
                        return
                try:
                    async with semaphore:
                        prev_page = prev_metadata.get(url) if args.update else None
                        page = await async_extract_page(
                            client=client,
                            url=url,
                            delay=args.delay,
                            browser=_browser,
                            cache=cache,
                            root=root,
                            prev_page=prev_page,
                        )
                        async with print_lock:
                            label = f"[{idx + 1:>{width}}/{total}]"
                            if page:
                                print(f"  {label} {url}")
                            else:
                                print(f"  {label} {url}  ← skipped (no content)")
                        results[idx] = page
                        if progress and page:
                            await progress.mark_done(url)
                except Exception as exc:
                    async with print_lock:
                        print(f"  ⚠  worker error [{idx}]: {exc}", file=sys.stderr)
                    results[idx] = None

            await asyncio.gather(*[_worker(i, url) for i, url in enumerate(urls)])
    finally:
        if _browser:
            await _browser.close()
        if _pw_handle:
            await _pw_handle.stop()

    pages: List[Dict] = []
    skipped = 0
    canonical_dedups = 0
    canonical_seen: Set[str] = set()
    for i in range(total):
        page = results.get(i)
        if page:
            url = urls[i]
            canonical_norm = normalize(page.get("canonical_url", url))
            if canonical_norm in canonical_seen and canonical_norm != normalize(url):
                canonical_dedups += 1
                skipped += 1
                continue
            canonical_seen.add(canonical_norm)
            pages.append(page)
        else:
            skipped += 1

    if progress and skipped == 0:
        progress.clear()
    return pages, skipped, canonical_dedups


# ── CLI ─────────────────────────────────────────────────────────────────────────
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="doc_ingester",
        description="Ingest a documentation website into a clean LLM-ready Markdown bundle.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python doc_ingester.py https://docs.maptiler.com\n"
            "  python doc_ingester.py https://docs.stripe.com --include api --exclude android\n"
            "  python doc_ingester.py https://fastapi.tiangolo.com --delay 0.5 --no-changelog\n"
            "  python doc_ingester.py https://docs.example.com --output-mode both\n"
            "  python doc_ingester.py https://docs.example.com --update\n"
            "  python doc_ingester.py https://docs.example.com --concurrency 10\n"
            "  python doc_ingester.py https://docs.example.com --snapshot\n"
            "  python doc_ingester.py https://docs.example.com --browser\n"
            "  python doc_ingester.py https://docs.example.com --zip\n"
            "  python doc_ingester.py --compare old_output/ new_output/\n"
            "\n\n"
            "Knowledge catalog layout:\n"
            "  python doc_ingester.py https://docs.stripe.com   -o knowledge/stripe\n"
            "  python doc_ingester.py https://docs.supabase.com -o knowledge/supabase\n"
            "\n\n"
            "Snapshot layout (--snapshot):\n"
            "  knowledge/stripe/\n"
            "  ├── 2025-06/   combined.md, llm-bundle.md, metadata.json, ...\n"
            "  ├── 2025-09/   combined.md, llm-bundle.md, metadata.json, ...\n"
            "  └── latest  →  2025-09/  (symlink)\n"
        ),
    )
    parser.add_argument(
        "url", nargs="?", help="Root URL of the documentation website to ingest"
    )
    parser.add_argument(
        "--output",
        "-o",
        default="output",
        metavar="DIR",
        help="Directory to write output files into (default: output/)",
    )
    parser.add_argument(
        "--max-pages",
        "-n",
        type=int,
        default=200,
        metavar="N",
        help="Maximum number of pages to fetch and process (default: 200)",
    )
    parser.add_argument(
        "--delay",
        "-d",
        type=float,
        default=0.3,
        metavar="SECS",
        help="Minimum seconds to wait between HTTP requests (default: 0.3)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=20.0,
        metavar="SECS",
        help="HTTP request timeout in seconds (default: 20)",
    )
    parser.add_argument(
        "--no-changelog",
        action="store_true",
        help="Exclude changelog, release-notes, and whats-new pages",
    )
    parser.add_argument(
        "--include",
        action="append",
        default=[],
        metavar="TERM",
        help="Only include URLs that contain TERM (case-insensitive). Repeatable: --include api --include sdk",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="TERM",
        help="Exclude URLs that contain TERM (case-insensitive). Repeatable: --exclude android --exclude ios",
    )
    parser.add_argument(
        "--update",
        action="store_true",
        help="Incremental mode: use the HTTP cache and content hashes to skip unchanged pages. Reports new / changed / unchanged / removed counts. Requires a previous run in the same output directory.",
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable HTTP caching (ETag / Last-Modified). Always re-fetches all pages.",
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=5,
        metavar="N",
        help="Number of pages to fetch in parallel (default: 5). Use 1 for strictly sequential. Raise carefully on large sites.",
    )
    parser.add_argument(
        "--output-mode",
        choices=["combined", "split", "both"],
        default="combined",
        metavar="MODE",
        help="Output mode: 'combined' (default) writes one combined.md; 'split' writes one file per page under pages/; 'both' writes both.",
    )
    parser.add_argument(
        "--browser",
        action="store_true",
        help="Use Playwright (headless Chromium) to render JS-heavy pages. Requires: pip install playwright && playwright install chromium",
    )
    parser.add_argument(
        "--snapshot",
        action="store_true",
        help="Write output to a timestamped snapshot subdirectory <output>/<YYYY-MM>/ and update <output>/latest symlink. Enables versioned documentation archives.",
    )
    parser.add_argument(
        "--zip",
        action="store_true",
        help="Compress the output directory into a .zip archive after writing.",
    )
    parser.add_argument(
        "--compare",
        nargs=2,
        metavar=("OLD_DIR", "NEW_DIR"),
        help="Diff two output directories by their metadata.json and exit.",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume a partial crawl. Loads progress.json from the output directory and skips URLs that were already successfully fetched. Useful when a large crawl was interrupted.",
    )
    parser.add_argument(
        "--doc-version",
        default=None,
        metavar="VER",
        help="Optional documentation version string to record in manifest.json (e.g. '2024-11-20', 'v3', 'latest'). Useful for historical archives of versioned documentation.",
    )
    return parser.parse_args()


# ── main ────────────────────────────────────────────────────────────────────────
def main() -> None:
    args = parse_args()

    if args.compare:
        compare_outputs(Path(args.compare[0]), Path(args.compare[1]))
        return

    if not args.url:
        print(
            "error: a URL is required  (or use --compare OLD_DIR NEW_DIR)",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.browser and not PLAYWRIGHT_AVAILABLE:
        sys.exit(
            "❌  --browser requires Playwright:\n"
            "    pip install playwright && playwright install chromium"
        )

    root = args.url.rstrip("/")
    if not root.startswith(("http://", "https://")):
        root = "https://" + root

    base_output_dir = Path(args.output)
    base_output_dir.mkdir(parents=True, exist_ok=True)
    if args.snapshot:
        output_dir = resolve_snapshot_dir(base_output_dir)
    else:
        output_dir = base_output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    cache: Optional[Cache] = None
    if not args.no_cache:
        cache = Cache(output_dir / ".cache")

    print(f"\n╔══ doc_ingester {VERSION} {'═' * (55 - len(VERSION))}═╗")
    print(f"║  Source  : {root}")
    print(f"║  Output  : {output_dir.resolve()}")
    print(
        f"║  Limit   : {args.max_pages} pages  |  delay {args.delay}s  |  timeout {args.timeout}s"
    )
    print(f"║  Workers : {args.concurrency} concurrent")
    if args.include:
        print(f"║  Include : {', '.join(args.include)}")
    if args.exclude:
        print(f"║  Exclude : {', '.join(args.exclude)}")

    flags = []
    if args.no_changelog:
        flags.append("no-changelog")
    if args.update:
        flags.append("incremental")
    if args.resume:
        flags.append("resume")
    if args.no_cache:
        flags.append("no-cache")
    if args.browser:
        flags.append("browser")
    if args.snapshot:
        flags.append("snapshot")
    if args.zip:
        flags.append("zip")
    if args.output_mode != "combined":
        flags.append(f"mode={args.output_mode}")
    if args.doc_version:
        flags.append(f"doc-version={args.doc_version}")
    if flags:
        print(f"║  Flags   : {', '.join(flags)}")
    print(f"╚{'═' * 67}╝\n")

    client = make_client(args.timeout)

    prev_metadata: Dict[str, Dict] = {}
    if args.update:
        prev_metadata = load_previous_metadata(output_dir)
        if prev_metadata:
            print(
                f"── Incremental mode: {len(prev_metadata)} pages from previous run\n"
            )
        else:
            print("── Incremental mode: no previous run found — doing full crawl\n")

    strategy, result = discover(
        client,
        root,
        args.max_pages,
        args.delay,
        args.no_changelog,
        args.include,
        args.exclude,
        cache,
    )

    if strategy == "llms-full":
        print(
            "\n── Writing outputs ────────────────────────────────────────────────────"
        )
        handle_llms_full(result, root, output_dir)
        if args.snapshot:
            update_latest_symlink(base_output_dir, output_dir)
        if args.zip:
            write_zip(output_dir)
        print(f"\n✅  Done  —  outputs written to {output_dir.resolve()}/")
        return

    raw_urls: List[str] = result
    if not raw_urls:
        sys.exit(
            "\n❌  No URLs discovered.\n"
            "    • Check that the URL is correct and publicly accessible.\n"
            "    • Try --delay 1.0 if you suspect rate-limiting.\n"
            "    • Try --browser if the site requires JavaScript.\n"
        )

    seen_norm: Set[str] = set()
    unique_urls: List[str] = []
    for u in raw_urls:
        key = normalize(u)
        if key not in seen_norm:
            seen_norm.add(key)
            unique_urls.append(u)
    unique_urls = unique_urls[: args.max_pages]
    total = len(unique_urls)
    print(
        f"\n── Fetching {total} pages  ({args.concurrency} workers) {'─' * max(0, 40 - len(str(total)))}"
    )

    progress: Optional[ProgressTracker] = None
    if args.resume:
        progress = ProgressTracker(output_dir)

    pages, skipped, canonical_dedups = asyncio.run(
        async_process_pages(
            urls=unique_urls,
            cache=cache,
            args=args,
            root=root,
            prev_metadata=prev_metadata,
            total=total,
            progress=progress,
        )
    )
    if not pages:
        sys.exit(
            "\n❌  No content was extracted from any page.\n"
            "    The site may require JavaScript (try --browser)\n"
            "    or authentication to access its content.\n"
        )

    incremental_stats: Optional[Dict] = None
    if args.update and prev_metadata:
        incremental_stats = _compute_incremental_stats(
            pages, prev_metadata, unique_urls
        )
        _print_incremental_summary(incremental_stats)

    print("\n── Writing outputs ────────────────────────────────────────────────────")
    if args.output_mode in ("combined", "both"):
        write_combined_md(pages, output_dir)
        write_llm_bundle(pages, output_dir)
    if args.output_mode in ("split", "both"):
        write_split_pages(pages, output_dir)

    write_urls_txt(unique_urls, output_dir)
    write_metadata(pages, root, strategy, output_dir)
    write_manifest(
        pages,
        root,
        strategy,
        output_dir,
        snapshot=output_dir.name if args.snapshot else None,
        doc_version=args.doc_version,
    )
    write_search_index(pages, output_dir)
    write_links_graph(pages, output_dir)
    extract_code_examples(pages, output_dir)
    write_docs_map(pages, root, output_dir)
    write_quality_report(
        pages,
        discovered=total,
        skipped=skipped,
        canonical_dedups=canonical_dedups,
        strategy=strategy,
        root=root,
        output_dir=output_dir,
        incremental_stats=incremental_stats,
    )

    if args.snapshot:
        update_latest_symlink(base_output_dir, output_dir)
    if args.zip:
        write_zip(output_dir)

    write_knowledge_catalog(base_output_dir)

    total_words = sum(p["word_count"] for p in pages)
    total_snippets = sum(1 for p in pages for _ in _CODE_FENCE.finditer(p["content"]))
    print(
        f"\n✅  Done\n"
        f"    {len(pages)} pages extracted  ({skipped} skipped)\n"
        f"    ~{total_words:,} words  |  {total_snippets} code snippets  |  strategy: {strategy}\n"
        f"    Output: {output_dir.resolve()}/"
    )
    if args.snapshot:
        print(f"    Snapshot: {output_dir.name}/  (latest → {output_dir.name})")


if __name__ == "__main__":
    main()
