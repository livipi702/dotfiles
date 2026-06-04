#!/usr/bin/env bash

export LC_ALL=C
set -euo pipefail

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required to run this script." >&2
  exit 1
fi

if ! command -v git &>/dev/null; then
  echo "Error: git CLI is required to run this script." >&2
  exit 1
fi

FROM_COMMIT=""
TO_COMMIT=""
MAX_FILE_LINES=1500
OUTPUT_FILE="git2ai_context.txt"
REPO_DIR="."
CUSTOM_IGNORES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  --from-commit)
    FROM_COMMIT="$2"
    shift 2
    ;;
  --to-commit)
    TO_COMMIT="$2"
    shift 2
    ;;
  --max-file-lines)
    MAX_FILE_LINES="$2"
    shift 2
    ;;
  -o | --output)
    OUTPUT_FILE="$2"
    shift 2
    ;;
  --ignore)
    CUSTOM_IGNORES+=("$2")
    shift 2
    ;;
  *)
    REPO_DIR="$1"
    shift
    ;;
  esac
done

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Error: '$REPO_DIR' is not a valid git repository." >&2
  exit 1
fi

cd "$REPO_DIR"

JOINED_IGNORES=""
if [ ${#CUSTOM_IGNORES[@]} -gt 0 ]; then
  JOINED_IGNORES=$(
    IFS=$'\t'
    printf '%s' "${CUSTOM_IGNORES[*]}"
  )
fi

# ==========================================
# ADVANCED PYTHON CONTEXT ENGINE
# ==========================================
python3 - "$FROM_COMMIT" "$TO_COMMIT" "$MAX_FILE_LINES" "$OUTPUT_FILE" "$JOINED_IGNORES" <<'EOF'
import sys
import os
import subprocess
import re
import fnmatch
import itertools
import json
import shutil
import tempfile
from collections import Counter
from xml.sax.saxutils import escape as xml_escape

FROM_COMMIT = sys.argv[1]
TO_COMMIT = sys.argv[2]
MAX_FILE_LINES = int(sys.argv[3])
OUTPUT_FILE = sys.argv[4]
CUSTOM_IGNORES = sys.argv[5].split('\t') if sys.argv[5] else []

BINARY_EXTS = {
    'png','jpg','jpeg','gif','pdf','zip','tar','gz','exe','dll','woff','woff2','ttf','eot','mp3','mp4','mov','avi',
    'bin','so','dylib','class','pyc','pyo','o','obj','a','lib','wasm','keystore','sqlite','db','ico',
    'svg','webp','bmp','tiff','mpg','mpeg','flv','ogg','wav','flac','jar','war','ear','apk','aab','app','dmg','iso',
    'pem', 'crt', 'key', 'p12', 'jks', 'pfx', 'asc', 'gpg', 'img', '7z', 'rar', 'lockb'
}
IGNORE_DIRS = {
    'node_modules','vendor','build','dist','out','coverage','.git','.svn','.hg','.bzr','.idea','.vscode','.vs',
    '.eclipse','.settings','.DS_Store','.docker','.terraform','.direnv','.local','.config','.nuget','.cargo',
    '.rustup','.npm','.yarn','.pnpm-store','.pnp','bower_components','.cache','.parcel-cache','.turbo','.vercel',
    '.netlify','__pycache__','.mypy_cache','.pytest_cache','.ruff_cache','.venv','venv','env','.tox','.nox',
    '.eggs','site-packages','.ipynb_checkpoints','.gradle','.mvn','.classpath','.bundle','target'
}

# ---------------------------------------------------------
# DEPENDENCY DETECTION: Universal Ctags
# ---------------------------------------------------------
HAS_CTAGS = False
if shutil.which("ctags"):
    try:
        ctags_test = subprocess.run(["ctags", "--version"], capture_output=True, text=True, timeout=2)
        if "Universal Ctags" in ctags_test.stdout:
            HAS_CTAGS = True
    except Exception:
        pass

# ---------------------------------------------------------
# REGEX FALLBACK
# ---------------------------------------------------------
SKELETON_REGEX = re.compile(
    r'^\s*(?:export\s+|public\s+|private\s+|protected\s+|static\s+|async\s+|abstract\s+|declare\s+|pub\s+)*(?:class|def|function|func|interface|struct|type|enum|protocol|extension|trait|impl|namespace)\s+[A-Za-z_]'
    r'|^\s*export\s+(?:const|let|var|default)\s+'
    r'|^\s*(?:public|private|protected)\s+(?:static\s+)?(?:[A-Za-z_<>]+\s+)[A-Za-z_]+\s*\('
    r'|^\s*type\s+[A-Za-z_]+\s*='
    r'|^\s*const\s+[A-Za-z_]+\s*=\s*(?:async\s+)?(?:\([^)]*\)\s*=>|=>)'
    r'|^\s*func\s+(?:\([^)]*\)\s*)?[A-Za-z_]+\s*\('
    r'|^\s*@(?:property|staticmethod|classmethod|dataclass|override|Injectable)',
    re.MULTILINE
)

def is_ignored(path):
    parts = path.split('/')
    if any(d in parts for d in IGNORE_DIRS): return True
    for pat in CUSTOM_IGNORES:
        if fnmatch.fnmatch(path, pat) or fnmatch.fnmatch(path, f"*/{pat}*"): return True
    ext = path.split('.')[-1].lower() if '.' in path else ''
    if ext in BINARY_EXTS: return True
    return False

def is_identity_file(path):
    name = os.path.basename(path).lower()
    if name in (
        'package.json', 'cargo.toml', 'pyproject.toml', 'go.mod', 'dockerfile', 'makefile', 'docker-compose.yml',
        'tsconfig.json', 'jest.config.js', 'jest.config.ts', 'vite.config.ts', 'vite.config.js', 
        'webpack.config.js', 'webpack.config.ts', 'babel.config.json', 'babel.config.js', 
        'requirements.txt', 'setup.py', 'pom.xml', 'build.gradle', '.gitlab-ci.yml', 'azure-pipelines.yml', 'jenkinsfile'
    ): return True
    if name.startswith('readme') or name.startswith('contributing') or name.startswith('changelog'): return True
    if '.github/workflows' in path: return True
    return False

def is_generated(path, content_bytes):
    name = os.path.basename(path).lower()
    if name.endswith('.min.js') or name.endswith('.min.css') or name.endswith('.tsbuildinfo') or name.endswith('.map'): return True
    if name.endswith('-lock.json') or name in ('yarn.lock', 'pnpm-lock.yaml', 'poetry.lock', 'go.sum'): return True
    header = content_bytes[:1024].decode('utf-8', errors='ignore').lower()
    if "auto-generated" in header or "do not edit" in header or "generated by" in header: return True
    return False

def read_exact(pipe, size):
    buf = bytearray()
    while len(buf) < size:
        chunk = pipe.read(size - len(buf))
        if not chunk: break
        buf.extend(chunk)
    return bytes(buf)

range_args = []
if FROM_COMMIT and TO_COMMIT: range_args = [f"{FROM_COMMIT}..{TO_COMMIT}"]
elif FROM_COMMIT: range_args = [f"{FROM_COMMIT}..HEAD"]
elif TO_COMMIT: range_args = [TO_COMMIT]
else: range_args = ["HEAD"]

target_head = subprocess.run(["git", "rev-parse", range_args[-1].split("..")[-1]], capture_output=True, text=True).stdout.strip()

# ==========================================
# PHASE 0: PRE-COMPUTE HOT FILES & METRICS
# ==========================================
log_cmd = ["git", "log", "-n", "2000", "--format=COMMIT|%an", "--name-only"] + range_args
proc = subprocess.run(log_cmd, capture_output=True, text=True, errors='replace')

file_churn = Counter()
commit_to_files = {}
file_authors = {}
current_commit = 0
current_author = "Unknown"

for line in proc.stdout.splitlines():
    line = line.strip()
    if not line: continue
    if line.startswith("COMMIT|"):
        current_commit += 1
        current_author = line.split('|')[1] if len(line.split('|')) > 1 else "Unknown"
        commit_to_files[current_commit] = set()
    else:
        if not is_ignored(line):
            commit_to_files[current_commit].add(line)
            file_churn[line] += 1
            if line not in file_authors: file_authors[line] = Counter()
            file_authors[line][current_author] += 1

co_change = Counter()
for fset in commit_to_files.values():
    if len(fset) > 30: continue
    for pair in itertools.combinations(sorted(list(fset)), 2):
        co_change[pair] += 1

hot_files = set([f for f, _ in file_churn.most_common(15)])
for (f1, f2), _ in co_change.most_common(15):
    hot_files.add(f1)
    hot_files.add(f2)

manifest_query = subprocess.run(["git", "ls-tree", "-r", "-z", target_head], capture_output=True)
all_files = []
identity_files = []
if manifest_query.returncode == 0:
    for record in manifest_query.stdout.split(b'\x00'):
        if not record: continue
        meta, raw_path = record.split(b'\t', 1)
        path = raw_path.decode('utf-8', errors='replace')
        if is_ignored(path): continue
        _, obj_type, obj_sha = meta.split(b' ')
        if obj_type == b'blob':
            file_record = (path, obj_sha)
            all_files.append(file_record)
            if is_identity_file(path): identity_files.append(file_record)

# ==========================================
# PHASE 0.5: BATCH CTAGS PRE-COMPUTATION
# ==========================================
ctags_cache = {}
if HAS_CTAGS and all_files:
    sys.stderr.write("Pre-computing symbols for large files via Universal Ctags...\n")
    with tempfile.TemporaryDirectory() as td:
        td_abs = os.path.abspath(td)
        temp_map = {}
        
        pre_stream = subprocess.Popen(["git", "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        for i, (path, obj_sha) in enumerate(all_files):
            if path in hot_files or is_identity_file(path):
                continue
                
            pre_stream.stdin.write(obj_sha + b'\n')
            pre_stream.stdin.flush()
            header = pre_stream.stdout.readline().strip().split(b' ')
            if len(header) < 3: continue
            size = int(header[2])
            raw = read_exact(pre_stream.stdout, size)
            read_exact(pre_stream.stdout, 1)
            
            if size == 0 or b'\x00' in raw[:1024] or is_generated(path, raw):
                continue
                
            text_for_count = raw.decode('utf-8', errors='replace')
            if len(text_for_count.splitlines()) > MAX_FILE_LINES:
                ext = os.path.splitext(path)[1]
                temp_name = f"f_{i}{ext}"
                temp_path = os.path.join(td_abs, temp_name)
                with open(temp_path, 'wb') as f:
                    f.write(raw)
                temp_map[temp_path] = path
                
        pre_stream.stdin.close()
        pre_stream.wait()
        
        if temp_map:
            cmd = ["ctags", "--output-format=json", "--fields=+nS", "-R", td_abs]
            proc = subprocess.run(cmd, capture_output=True)
            if proc.returncode == 0 and proc.stdout:
                TARGET_KINDS = {
                    'class', 'method', 'function', 'interface', 'struct', 
                    'enum', 'type', 'namespace', 'trait', 'impl', 'module', 
                    'typedef', 'macro', 'property'
                }
                for line in proc.stdout.split(b'\n'):
                    line = line.strip()
                    if not line: continue
                    try:
                        tag = json.loads(line.decode('utf-8', errors='replace'))
                        kind = tag.get('kind', '').lower()
                        if kind in TARGET_KINDS:
                            t_path = os.path.abspath(tag.get('path', ''))
                            if t_path in temp_map:
                                orig_path = temp_map[t_path]
                                name = tag.get('name', '')
                                line_num = tag.get('line', 0)
                                sig = tag.get('signature', '')
                                scope = tag.get('scope', '')
                                indent = "  " if scope else ""
                                display = f"{indent}{kind} {name}{sig}"
                                
                                if orig_path not in ctags_cache:
                                    ctags_cache[orig_path] = []
                                ctags_cache[orig_path].append((line_num, display))
                    except Exception:
                        continue
                        
        for p in ctags_cache:
            ctags_cache[p].sort(key=lambda x: x[0])
            ctags_cache[p] = [s[1] for s in ctags_cache[p]]

out = open(OUTPUT_FILE, "w", encoding="utf-8", errors="replace")
out.write('<?xml version="1.0" encoding="UTF-8"?>\n<git2ai_export>\n')

object_stream = subprocess.Popen(["git", "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

def print_file_content(path, obj_sha, skip_skeleton=False):
    object_stream.stdin.write(obj_sha + b'\n')
    object_stream.stdin.flush()
    header = object_stream.stdout.readline().strip().split(b' ')
    if len(header) < 3: return
    size = int(header[2])
    raw = read_exact(object_stream.stdout, size)
    read_exact(object_stream.stdout, 1)
    
    if size == 0:
        out.write(f'  <file path="{xml_escape(path)}" empty="true" />\n')
        return
    if is_generated(path, raw):
        out.write(f'  <file path="{xml_escape(path)}" omitted="true" reason="auto-generated or lockfile" />\n')
        return
    if b'\x00' in raw[:1024]:
        out.write(f'  <file path="{xml_escape(path)}" omitted="true" reason="binary_content" />\n')
        return
        
    text = raw.decode('utf-8', errors='replace')
    lines = text.splitlines()
    
    out.write(f'  <file path="{xml_escape(path)}">\n    <![CDATA[\n')
    
    if skip_skeleton or len(lines) <= MAX_FILE_LINES:
        for line in lines:
            out.write(line.replace("]]>", "] ]>") + "\n")
    else:
        out.write(f"/* ... [LARGE FILE: {len(lines)} LINES. EXTRACTING SEMANTIC SKELETON TO SAVE WINDOW] ... */\n\n")
        
        if path in ctags_cache:
            out.write("/* Universal Ctags Extracted Outline */\n")
            for s_line in ctags_cache[path]:
                out.write(s_line.replace("]]>", "] ]>") + "\n")
        else:
            extracted = 0
            capturing_multiline = False
            
            for line in lines:
                if not capturing_multiline:
                    if SKELETON_REGEX.search(line):
                        out.write(line.replace("]]>", "] ]>") + "\n")
                        extracted += 1
                        if not ("{" in line or ";" in line or line.strip().endswith(")")):
                            capturing_multiline = True
                else:
                    out.write(line.replace("]]>", "] ]>") + "\n")
                    if "{" in line or ";" in line or line.strip().endswith(")"):
                        capturing_multiline = False
                        
            if extracted == 0:
                for idx in range(min(len(lines), 100)): out.write(lines[idx].replace("]]>", "] ]>") + "\n")
                out.write("\n/* ... [NO INTERFACE DETECTED. TRUNCATED.] ... */\n")
            
    out.write("    ]]>\n  </file>\n")

# ==========================================
# PHASE 1: PROJECT IDENTITY
# ==========================================
out.write("<project_identity>\n  <note>Core orientation files, manifests, and documentation. Always prioritized.</note>\n")
for path, obj_sha in identity_files:
    print_file_content(path, obj_sha, skip_skeleton=True)
out.write("</project_identity>\n")

# ==========================================
# PHASE 2: DIRECTORY STRUCTURE & TEST MAP
# ==========================================
out.write("<directory_structure>\n  <![CDATA[\n")
filesystem = {}
for path, _ in all_files:
    cursor = filesystem
    for node in path.split('/'): cursor = cursor.setdefault(node, {})

def render_tree(node, prefix=""):
    keys = sorted(node.keys())
    for i, key in enumerate(keys):
        is_last = (i == len(keys) - 1)
        out.write(f"{prefix}{'└── ' if is_last else '├── '}{key}{'/' if node[key] else ''}\n")
        if node[key]: render_tree(node[key], prefix + ("    " if is_last else "│   "))
render_tree(filesystem)
out.write("  ]]>\n</directory_structure>\n")

out.write("<test_mappings>\n")
all_path_strs = set([p[0] for p in all_files])
for p in all_path_strs:
    dir_part = os.path.dirname(p)
    base = os.path.basename(p)
    name, _, ext = base.rpartition('.')
    if not ext or 'test' in name or 'spec' in name: continue
    
    candidates = [
        os.path.join(dir_part, f"{name}.test.{ext}"),
        os.path.join(dir_part, f"{name}.spec.{ext}"),
        os.path.join(dir_part, f"test_{base}"),
        os.path.join(dir_part, "tests", f"test_{base}"),
        os.path.join(dir_part, "tests", f"{name}.test.{ext}"),
        os.path.join(dir_part, "__tests__", f"{name}.test.{ext}")
    ]
    for c in candidates:
        c_clean = c.replace('\\', '/')
        if c_clean in all_path_strs:
            out.write(f'  <mapping source="{xml_escape(p)}" test="{xml_escape(c_clean)}" />\n')
            break
out.write("</test_mappings>\n")

# ==========================================
# PHASE 3 & 4: CURRENT STATE & SKELETONS
# ==========================================
out.write("<current_state>\n  <note>Files under line threshold are full. Truly massive files are reduced to Skeletons.</note>\n")
identity_paths = set(p[0] for p in identity_files)
for path, obj_sha in all_files:
    if path in identity_paths: continue
    skip_skeleton = (path in hot_files)
    print_file_content(path, obj_sha, skip_skeleton)
out.write("</current_state>\n")
object_stream.stdin.close()
object_stream.wait()

# ==========================================
# PHASE 4.5: UNCOMMITTED CHANGES
# ==========================================
dirty_check = subprocess.run(["git", "diff", "HEAD"], capture_output=True, text=True, errors='replace')
if dirty_check.stdout.strip():
    out.write("<uncommitted_changes>\n  <note>Working tree changes not yet committed.</note>\n  <![CDATA[\n")
    dirty_lines = dirty_check.stdout.splitlines()
    for idx in range(min(len(dirty_lines), 500)):
        out.write(dirty_lines[idx].replace("]]>", "] ]>") + "\n")
    if len(dirty_lines) > 500:
        out.write("\n... [UNCOMMITTED CHANGES TRUNCATED AFTER 500 LINES] ...\n")
    out.write("  ]]>\n</uncommitted_changes>\n")

# ==========================================
# PHASE 5: RECENT ACTIVITY WINDOW
# ==========================================
out.write("<recent_activity>\n  <note>The last 20 commits for immediate active context.</note>\n  <![CDATA[\n")
recent_proc = subprocess.Popen(["git", "log", "-n", "20", "-p", "--date=short"], stdout=subprocess.PIPE, text=True, errors='replace')
commit_lines = 0
for line in recent_proc.stdout:
    if line.startswith("commit "): commit_lines = 0
    if commit_lines < 1000:
        out.write(line.replace("]]>", "] ]>"))
        commit_lines += 1
    elif commit_lines == 1000:
        out.write("\n... [DIFF TRUNCATED TO 1000 LINES] ...\n")
        commit_lines += 1
out.write("  ]]>\n</recent_activity>\n")

# ==========================================
# PHASE 6: RANGE-FILTERED HISTORY
# ==========================================
out.write("<history>\n  <note>Filtered repository history. Capped at 500 commits.</note>\n  <![CDATA[\n")
is_head_range = (range_args == ["HEAD"] or range_args[-1].endswith("..HEAD"))
hist_cmd = ["git", "log", "-n", "500", "-p", "--diff-filter=ACDMRT", "--date=short"]
if is_head_range: hist_cmd.extend(["--skip", "20"])
hist_cmd.extend(range_args)

hist_proc = subprocess.Popen(hist_cmd, stdout=subprocess.PIPE, text=True, errors='replace')
commit_lines = 0
for line in hist_proc.stdout:
    if line.startswith("commit "): commit_lines = 0
    if commit_lines < 1000:
        out.write(line.replace("]]>", "] ]>"))
        commit_lines += 1
    elif commit_lines == 1000:
        out.write("\n... [DIFF TRUNCATED TO 1000 LINES] ...\n")
        commit_lines += 1
out.write("  ]]>\n</history>\n")

# ==========================================
# PHASE 7: COMPACT DERIVED SIGNALS
# ==========================================
out.write("<development_dynamics>\n")
out.write("  <change_frequency_hotspots>\n")
for path, count in file_churn.most_common(15):
    if count > 1: out.write(f'    <file path="{xml_escape(path)}" modifications="{count}" />\n')
out.write("  </change_frequency_hotspots>\n")
out.write("  <logical_coupling>\n")
for (p1, p2), count in co_change.most_common(15):
    if count > 1: out.write(f'    <coupled_pair file_a="{xml_escape(p1)}" file_b="{xml_escape(p2)}" co_commits="{count}" />\n')
out.write("  </logical_coupling>\n")
out.write("  <contested_ownership>\n")
contested = []
for path, authors in file_authors.items():
    if len(authors) > 1: contested.append((path, len(authors), authors.most_common(1)[0][0]))
contested.sort(key=lambda x: x[1], reverse=True)
for path, count, primary in contested[:10]:
    out.write(f'    <file path="{xml_escape(path)}" total_contributors="{count}" primary_author="{xml_escape(primary)}" />\n')
out.write("  </contested_ownership>\n")
out.write("</development_dynamics>\n")
out.write("</git2ai_export>\n")
out.close()

export_weight_mb = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)
sys.stderr.write(f"\nContext Output: {OUTPUT_FILE} ({export_weight_mb:.1f} MB)\n")
EOF
