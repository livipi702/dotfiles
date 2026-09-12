#!/usr/bin/env bash
# concat.sh v4.1 — Directory Merger

set -uo pipefail
set +e 2>/dev/null || true

readonly VERSION="4.1.0"

# ── Exit Codes ───────────────────────────────────────────
readonly EX_OK=0
readonly EX_ERR=1
readonly EX_USAGE=2
readonly EX_NOINPUT=66
readonly EX_CANTCREAT=73
readonly EX_NOPERM=77

# ── Binary Extensions ───────────────────────────────────
readonly BINARY_EXTS='png,jpg,jpeg,gif,bmp,ico,webp,exe,dll,so,dylib,zip,tar,gz,rar,7z,pdf,doc,docx,xls,xlsx,ppt,pptx,mp3,mp4,avi,mov,woff,woff2,ttf,eot,otf,class,o,pyc,pyo,db,sqlite,iso,dmg,apk,war,ear,jar,nupkg,whl'

# ── Global State ────────────────────────────────────────
QUIET=0
VERBOSE=0
DRY_RUN=0
MAX_SIZE=0
CLI_NO_COLOR=0
LOCK_FILE=""
SCHEMA=0
DEPS=0
CHUNK_SIZE=0

# ── Colors ──────────────────────────────────────────────
_setup_colors() {
  local use_color=1
  [[ -n "${NO_COLOR:-}" ]] && use_color=0
  [[ "$CLI_NO_COLOR" -eq 1 ]] && use_color=0
  [[ ! -t 1 ]] && use_color=0

  if [[ "$use_color" -eq 0 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    WHITE=''
    BOLD=''
    DIM=''
    NC=''
  else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
  fi
}

# ── UI Helpers ──────────────────────────────────────────
die() {
  local code msg
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    code="$1"
    shift
    msg="$*"
  else
    code="$EX_ERR"
    msg="$*"
  fi
  echo -e "\n${RED}✖ Error:${NC} $msg\n" >&2
  exit "$code"
}

warn() { [[ "$QUIET" -eq 0 ]] && echo -e "${YELLOW}⚠${NC} $*" >&2; }
info() { [[ "$QUIET" -eq 0 ]] && echo -e "${CYAN}▸${NC} $*"; }
ok() { [[ "$QUIET" -eq 0 ]] && echo -e "${GREEN}✔${NC} $*"; }
verbose() { [[ "$VERBOSE" -eq 1 ]] && echo -e "${DIM}  $*${NC}" >&2; }

ask() {
  local prompt="$1" default="${2:-}" response
  if [[ -n "$default" ]]; then
    echo -ne "${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: " >&2
  else
    echo -ne "${CYAN}${prompt}${NC}: " >&2
  fi
  read -r response || response=""
  echo "${response:-$default}"
}

# ── Usage ───────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: concat.sh [OPTIONS] [DIRECTORY]

Concatenate files from a directory into a single output for AI context
or human reading.

Options:
  --ai              AI context format (XML, default)
  --human           Human-readable format (Markdown)
  -o, --output FILE Output file path
  -q, --quiet       Suppress non-error output
  -v, --verbose     Show verbose/debug output
  --dry-run         Preview files without writing output
  --max-size SIZE   Skip files larger than SIZE (e.g. 100K, 5M)
  --schema          Generate XSD schema alongside AI context output
  --deps            Scan and include dependency graph (imports/requires)
  --chunk-size N    Split output into chunks of N files with manifest
  --no-color        Disable colored output
  --force           Overwrite output without prompting (CLI mode)
  -h, --help        Show this help message

Without arguments, runs in interactive mode (requires fzf).

Examples:
  concat.sh                        # Interactive mode
  concat.sh ./src                  # Concatenate src/ as AI context
  concat.sh --human ./src -o out   # Human-readable, custom output
  concat.sh --dry-run ./src        # Preview only
  concat.sh --max-size 50K ./src   # Skip files > 50KB
  concat.sh --schema --deps ./src  # AI context + XSD + dependency graph
  concat.sh --chunk-size 50 ./src  # Split into 50-file chunks
EOF
}

# ── Dependency Check ────────────────────────────────────
check_deps() {
  local require_fzf="${1:-0}"
  local missing=()
  command -v rg >/dev/null 2>&1 || missing+=("ripgrep (rg)")
  command -v awk >/dev/null 2>&1 || missing+=("awk")
  [[ "$require_fzf" -eq 1 ]] && { command -v fzf >/dev/null 2>&1 || missing+=("fzf"); }
  [[ ${#missing[@]} -gt 0 ]] && die "$EX_ERR" "Missing dependencies: ${missing[*]}"
}

# ── Temp Files ──────────────────────────────────────────
list_file=$(mktemp "${TMPDIR:-/tmp}/concat_list_XXXXXX")
stats_file=$(mktemp "${TMPDIR:-/tmp}/concat_stats_XXXXXX")
trap 'rm -f "$list_file" "$stats_file" ${LOCK_FILE:-}' EXIT INT TERM HUP

# ── Size Parser ─────────────────────────────────────────
parse_size() {
  local input="$1" num unit
  if [[ "$input" =~ ^([0-9]+)([KkMmGg]?)$ ]]; then
    num="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2],,}"
    case "$unit" in
    k) echo $((num * 1024)) ;;
    m) echo $((num * 1048576)) ;;
    g) echo $((num * 1073741824)) ;;
    *) echo "$num" ;;
    esac
  else
    die "$EX_USAGE" "Invalid size format: $input (use e.g. 100K, 5M, 1G)"
  fi
}

# ── RG Runner ──────────────────────────────────────────
# FIX: rg already respects .gitignore natively. When we also manually parse
# the ignore file and add -g flags, the two mechanisms conflict and can
# produce zero results. Solution: add --no-ignore-vcs when we handle the
# ignore file manually, so rg doesn't double-apply it.
run_rg() {
  local target_dir="$1"
  local rg_args=(
    --files --hidden
    -g '!.git/'
    -g '!node_modules/'
    -g '!.venv/'
    -g '!__pycache__/'
  )

  # Split binary extensions into individual -g flags for compatibility
  # (avoids potential issues with very long brace-expansion globs)
  IFS=',' read -ra _exts <<<"$BINARY_EXTS"
  for _ext in "${_exts[@]}"; do
    rg_args+=(-g "!*.$_ext")
  done

  # Load .concatignore if present, fall back to .gitignore
  local ignore_file=""
  if [[ -f "${target_dir}/.concatignore" ]]; then
    ignore_file="${target_dir}/.concatignore"
  elif [[ -f "${target_dir}/.gitignore" ]]; then
    ignore_file="${target_dir}/.gitignore"
  fi

  if [[ -n "$ignore_file" ]]; then
    verbose "Using ignore rules from: $ignore_file"
    # FIX: disable rg's native VCS ignore so we don't double-apply the same
    # .gitignore rules — this was the primary cause of zero-file results.
    rg_args+=(--no-ignore-vcs)

    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" == \#* ]] && continue
      # Skip negation patterns — complex to translate and rarely needed
      # (they re-include files that were excluded; just leave them included)
      [[ "$line" == \!* ]] && continue
      # Strip leading slash (gitignore anchors, rg globs don't need it)
      line="${line#/}"
      [[ -z "$line" ]] && continue
      rg_args+=(-g "!$line")
    done <"$ignore_file"
  fi

  rg_args+=("$target_dir")

  if [[ "$MAX_SIZE" -gt 0 ]]; then
    # FIX: use a temp file to preserve rg's exit code outside the while subshell
    local rg_out
    rg_out=$(mktemp "${TMPDIR:-/tmp}/concat_rg_XXXXXX")
    rg "${rg_args[@]}" >"$rg_out" || {
      rm -f "$rg_out"
      return 1
    }
    while IFS= read -r fpath; do
      local fsize
      fsize=$(wc -c <"$fpath" 2>/dev/null | tr -d ' ') || continue
      [[ "$fsize" -le "$MAX_SIZE" ]] && echo "$fpath"
    done <"$rg_out"
    rm -f "$rg_out"
  else
    rg "${rg_args[@]}"
  fi
}

# ── Lock File ──────────────────────────────────────────
acquire_lock() {
  local out_file="$1"
  LOCK_FILE="${out_file}.lock"
  if [[ -f "$LOCK_FILE" ]]; then
    local lock_pid
    lock_pid=$(head -n1 "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
      die "$EX_ERR" "Another concat process (PID $lock_pid) is writing to $out_file"
    fi
    warn "Stale lock file found, removing"
    rm -f "$LOCK_FILE"
  fi
  echo "$$" >"$LOCK_FILE"
  verbose "Acquired lock: $LOCK_FILE"
}

release_lock() {
  if [[ -n "${LOCK_FILE:-}" && -f "$LOCK_FILE" ]]; then
    rm -f "$LOCK_FILE"
    verbose "Released lock: $LOCK_FILE"
  fi
  LOCK_FILE=""
}

# ── Input Validation ───────────────────────────────────
validate_inputs() {
  local target_dir="$1" out_file="$2" out_dir
  [[ ! -d "$target_dir" ]] && die "$EX_NOINPUT" "Not a directory: $target_dir"
  [[ ! -r "$target_dir" ]] && die "$EX_NOPERM" "Cannot read directory: $target_dir"
  out_dir=$(dirname "$out_file")
  [[ ! -d "$out_dir" ]] && die "$EX_NOINPUT" "Output directory does not exist: $out_dir"
  [[ ! -w "$out_dir" ]] && die "$EX_NOPERM" "Cannot write to directory: $out_dir"
}

# ── Schema Generator ────────────────────────────────────
generate_schema() {
  local xsd_file="$1"
  cat >"$xsd_file" <<'XSD'
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <xs:element name="repository_context" type="RepositoryContextType" />

  <xs:complexType name="RepositoryContextType">
    <xs:sequence>
      <xs:element name="metadata"         type="MetadataType"      minOccurs="1" maxOccurs="1" />
      <xs:element name="repository_index" type="IndexType"         minOccurs="1" maxOccurs="1" />
      <xs:element name="dependencies"     type="DependenciesType"  minOccurs="0" maxOccurs="1" />
      <xs:element name="files"            type="FilesType"         minOccurs="1" maxOccurs="1" />
    </xs:sequence>
    <xs:attribute name="chunk" type="xs:string" use="optional" />
  </xs:complexType>

  <xs:complexType name="MetadataType">
    <xs:attribute name="directory"      type="xs:string"   use="required" />
    <xs:attribute name="timestamp"      type="xs:dateTime" use="required" />
    <xs:attribute name="schema_version" type="xs:string"   use="optional" />
  </xs:complexType>

  <xs:complexType name="IndexType">
    <xs:sequence>
      <xs:element name="path" type="xs:string" minOccurs="0" maxOccurs="unbounded" />
    </xs:sequence>
  </xs:complexType>

  <xs:complexType name="DependenciesType">
    <xs:sequence>
      <xs:element name="edge" type="EdgeType" minOccurs="0" maxOccurs="unbounded" />
    </xs:sequence>
  </xs:complexType>

  <xs:complexType name="EdgeType">
    <xs:attribute name="source" type="xs:string" use="required" />
    <xs:attribute name="target" type="xs:string" use="required" />
    <xs:attribute name="type"   type="xs:string" use="optional" />
  </xs:complexType>

  <xs:complexType name="FilesType">
    <xs:sequence>
      <xs:element name="file" type="FileType" minOccurs="0" maxOccurs="unbounded" />
    </xs:sequence>
  </xs:complexType>

  <xs:complexType name="FileType" mixed="true">
    <xs:sequence>
      <xs:any processContents="skip" minOccurs="0" maxOccurs="unbounded" />
    </xs:sequence>
    <xs:attribute name="path"      type="xs:string"  use="required" />
    <xs:attribute name="extension" type="xs:string"  use="required" />
    <xs:attribute name="lines"     type="xs:integer" use="required" />
    <xs:attribute name="chars"     type="xs:integer" use="required" />
  </xs:complexType>

</xs:schema>
XSD
  verbose "Schema written: $xsd_file"
}

# ── Dependency Scanner ──────────────────────────────────
scan_deps() {
  local target_dir="$1" deps_file="$2"
  rg --files --hidden \
    -g '!.git/' -g '!node_modules/' -g '!.venv/' -g '!__pycache__/' \
    "$target_dir" 2>/dev/null | awk -v dir="$target_dir" '
  BEGIN { prefix = dir "/" }
  {
    filepath = $0
    rel = (index(filepath, prefix) == 1) ? substr(filepath, length(prefix) + 1) : filepath
    sub("^/", "", rel)

    while ((getline line < filepath) > 0) {
      target = ""; type = ""

      if (match(line, /require\(["'"'"'][^)"'"'"']+["'"'"']\)/)) {
        s = RSTART + 9; l = RLENGTH - 11
        target = substr(line, s, l); gsub(/["'"'"']/, "", target); type = "require"
      } else if (match(line, /from[ \t]+["'"'"'][^"'"'"']+["'"'"']/)) {
        rest = substr(line, RSTART)
        if (match(rest, /["'"'"'][^"'"'"']+["'"'"']/))
          target = substr(rest, RSTART + 1, RLENGTH - 2)
        type = "import"
      } else if (match(line, /^import[ \t]+["'"'"'][^"'"'"']+["'"'"']/)) {
        rest = substr(line, RSTART)
        if (match(rest, /["'"'"'][^"'"'"']+["'"'"']/))
          target = substr(rest, RSTART + 1, RLENGTH - 2)
        type = "import"
      } else if (match(line, /^import[ \t]+[a-zA-Z_][a-zA-Z0-9_.]*/)) {
        target = substr(line, RSTART + 7)
        gsub(/ .*/, "", target); gsub(/\./, "/", target); type = "import"
      } else if (match(line, /^from[ \t]+[a-zA-Z_][a-zA-Z0-9_.]*/)) {
        target = substr(line, RSTART + 5)
        sub(/[ \t].*/, "", target); gsub(/\./, "/", target); type = "import"
      } else if (match(line, /#include[ \t]*"[^"]+"/)) {
        rest = substr(line, RSTART)
        if (match(rest, /"[^"]+"/))
          target = substr(rest, RSTART + 1, RLENGTH - 2)
        type = "include"
      } else if (match(line, /^import[ \t]+"[^"]+"/)) {
        rest = substr(line, RSTART)
        if (match(rest, /"[^"]+"/))
          target = substr(rest, RSTART + 1, RLENGTH - 2)
        type = "import"
      } else if (match(line, /^(source|[.])[ \t]+[a-zA-Z0-9_./-]+/)) {
        rest = substr(line, RSTART)
        sub(/^(source|[.])[ \t]+/, "", rest); sub(/[ \t].*/, "", rest)
        target = rest; type = "source"
      }

      if (target != "" && target !~ /^\/|^https?:|^@|^\./)
        printf "%s\t%s\t%s\n", rel, target, type
    }
    close(filepath)
  }' >"$deps_file" 2>/dev/null || true
  verbose "Dependencies scanned: $deps_file"
}

# ── DOT Graph Generator ─────────────────────────────────
generate_dot() {
  local deps_file="$1" dot_file="$2"
  [[ ! -s "$deps_file" ]] && {
    verbose "No dependencies found, skipping DOT generation"
    return 0
  }
  {
    echo 'digraph dependencies {'
    echo '  rankdir=LR;'
    echo '  node [shape=box, fontsize=10];'
    echo '  edge [fontsize=8];'
    awk -F'\t' '{ printf "  \"%s\" -> \"%s\" [label=\"%s\"];\n", $1, $2, $3 }' "$deps_file"
    echo '}'
  } >"$dot_file"
  verbose "DOT graph written: $dot_file"
}

# ── AWK Processor (shared between do_concat and chunk_stream) ────────────────
_run_awk() {
  local target_dir="$1" date="$2" format_type="$3"
  local input_list="$4" stats_out="$5" total_count="$6"
  local xsd_ref="${7:-}" chunk_num="${8:-0}" chunk_total="${9:-0}"

  awk -v dir="$target_dir" \
    -v date="$date" \
    -v format="$format_type" \
    -v list="$input_list" \
    -v stats="$stats_out" \
    -v progress="$VERBOSE" \
    -v total="$total_count" \
    -v xsd_ref="$xsd_ref" \
    -v chunk_num="$chunk_num" \
    -v chunk_total="$chunk_total" '
  BEGIN {
    total_files = 0; total_lines = 0; total_chars = 0; skipped = 0

    if (format == "ai") {
      if (chunk_num > 0) {
        printf "<repository_context chunk=\"%d/%d\">\n", chunk_num, chunk_total
        printf "<metadata directory=\"%s\" timestamp=\"%s\" />\n\n", dir, date
      } else {
        print "<repository_context"
        print "  xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""
        if (xsd_ref != "")
          printf "  xsi:noNamespaceSchemaLocation=\"%s\">\n", xsd_ref
        else
          print ">"
        printf "<metadata directory=\"%s\" timestamp=\"%s\" schema_version=\"%s\" />\n\n", dir, date, "4.1"
      }
      print "<repository_index>"
      while ((getline p < list) > 0) {
        prefix = dir "/"
        rel_p = (index(p, prefix) == 1) ? substr(p, length(prefix) + 1) : p
        sub("^/", "", rel_p)
        printf "<path>%s</path>\n", rel_p
      }
      close(list)
      print "</repository_index>\n"
      print "<files>"
    } else {
      if (chunk_num > 0)
        printf "# Chunk %d/%d\n", chunk_num, chunk_total
      else
        print "# Project Directory Dump"
      printf "**Path:** `%s`  \n**Generated:** `%s`\n\n---\n\n", dir, date
    }
  }

  {
    filepath = $0
    prefix = dir "/"
    rel_path = (index(filepath, prefix) == 1) ? substr(filepath, length(prefix) + 1) : filepath
    sub("^/", "", rel_path)

    ext = rel_path
    ext = (match(ext, /\.[^.]+$/)) ? substr(ext, RSTART + 1) : "txt"

    if (progress == "1")
      printf "\r  [%d/%d] %s", total_files + skipped + 1, total + 0, rel_path > "/dev/stderr"

    file_lines = 0; file_chars = 0; n = 0
    while ((getline line < filepath) > 0) {
      stored[n] = line; n++
      file_lines++; file_chars += length(line) + 1
    }

    if (ERRNO != "" && n == 0) {
      close(filepath); skipped++
      if (progress == "1")
        printf "\r  Skipping unreadable: %s\n", rel_path > "/dev/stderr"
      next
    }
    close(filepath)

    if (format == "ai") {
      printf "<file path=\"%s\" extension=\"%s\" lines=\"%d\" chars=\"%d\">\n",
             rel_path, ext, file_lines, file_chars
      print "<![CDATA["
      for (i = 0; i < n; i++) {
        gsub(/\]\]>/, "]]>]]><![CDATA[", stored[i])
        print stored[i]; delete stored[i]
      }
      print "]]></file>\n"
    } else {
      printf "### `%s`\n", rel_path
      printf "*Lines: %d | Chars: %d*\n\n", file_lines, file_chars
      printf "```%s\n", ext
      for (i = 0; i < n; i++) { print stored[i]; delete stored[i] }
      print "```\n\n---\n"
    }

    total_lines += file_lines; total_chars += file_chars; total_files++
  }

  END {
    if (format == "ai") print "</files>\n</repository_context>"
    if (progress == "1") {
      if (skipped > 0) printf "\r  Skipped %d unreadable file(s)\n", skipped > "/dev/stderr"
      printf "\n" > "/dev/stderr"
    }
    printf("%d|%d|%d\n", total_files, total_lines, total_chars) > stats
  }' "$input_list"
}

# ── Chunk Streamer ──────────────────────────────────────
chunk_stream() {
  local target_dir="$1" out_file="$2" format_type="${3:-ai}" chunk_size="$4"
  local total_files
  total_files=$(wc -l <"$list_file" | tr -d ' ')
  local num_chunks=$(((total_files + chunk_size - 1) / chunk_size))

  info "Streaming $total_files files in $num_chunks chunk(s) of $chunk_size"

  local out_dir out_base out_name
  out_dir=$(dirname "$out_file")
  out_base=$(basename "$out_file")
  out_name="${out_base%.*}"

  local manifest_file="${out_dir}/${out_name}-manifest.json"
  printf '{"version":"%s","directory":"%s","timestamp":"%s","total_files":%d,"chunk_size":%d,"chunks":[' \
    "$VERSION" "$target_dir" "$(date '+%Y-%m-%dT%H:%M:%S')" "$total_files" "$chunk_size" >"$manifest_file"

  local chunk_idx=0 line_offset=0 remaining=$total_files

  while [[ "$remaining" -gt 0 ]]; do
    chunk_idx=$((chunk_idx + 1))
    local end_line=$((line_offset + chunk_size))
    [[ "$end_line" -gt "$total_files" ]] && end_line="$total_files"
    local files_in_chunk=$((end_line - line_offset))

    local chunk_list_file
    chunk_list_file=$(mktemp "${TMPDIR:-/tmp}/concat_chunk_XXXXXX")
    awk -v s="$((line_offset + 1))" -v e="$end_line" \
      'NR >= s && NR <= e { print }' "$list_file" >"$chunk_list_file"

    local chunk_out="${out_dir}/${out_name}-chunk${chunk_idx}.${out_base##*.}"
    local tmp_out
    tmp_out=$(mktemp "${TMPDIR:-/tmp}/concat_chunk_out_XXXXXX") || {
      rm -f "$chunk_list_file"
      die "$EX_CANTCREAT" "Failed to create temp chunk file"
    }

    local awk_rc=0
    _run_awk "$target_dir" "$(date '+%Y-%m-%dT%H:%M:%S')" "$format_type" \
      "$chunk_list_file" "$stats_file" "$files_in_chunk" \
      "" "$chunk_idx" "$num_chunks" >>"$tmp_out" || awk_rc=$?

    if [[ "$awk_rc" -ne 0 ]]; then
      rm -f "$tmp_out" "$chunk_list_file"
      die "$EX_ERR" "Chunk $chunk_idx failed (awk exit $awk_rc)"
    fi

    [[ ! -s "$tmp_out" ]] && {
      rm -f "$tmp_out" "$chunk_list_file"
      die "$EX_ERR" "Chunk $chunk_idx produced no output"
    }

    mv -f "$tmp_out" "$chunk_out" || {
      rm -f "$tmp_out" "$chunk_list_file"
      die "$EX_CANTCREAT" "Failed to write chunk: $chunk_out"
    }

    rm -f "$chunk_list_file"

    [[ "$chunk_idx" -gt 1 ]] && printf ',' >>"$manifest_file"
    printf '{"index":%d,"file":"%s","files":%d}' "$chunk_idx" "$chunk_out" "$files_in_chunk" >>"$manifest_file"
    ok "Chunk $chunk_idx/$num_chunks → $(basename "$chunk_out")"

    line_offset=$end_line
    remaining=$((remaining - files_in_chunk))
  done

  printf ']}\n' >>"$manifest_file"

  if [[ "$SCHEMA" -eq 1 && "$format_type" == "ai" ]]; then
    generate_schema "${out_dir}/${out_name}.xsd"
  fi
  if [[ "$DEPS" -eq 1 ]]; then
    local deps_file="${out_dir}/${out_name}-deps.tsv"
    scan_deps "$target_dir" "$deps_file"
    generate_dot "$deps_file" "${out_dir}/${out_name}-deps.dot"
  fi

  echo
  ok "Manifest: $manifest_file"
  ok "Chunks  : $num_chunks"
  echo
}

# ── Core Engine ─────────────────────────────────────────
do_concat() {
  local target_dir="$1" out_file="$2" format_type="${3:-ai}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run — files that would be included:"
    local count=0
    while IFS= read -r fpath; do
      count=$((count + 1))
      local rel="${fpath#"$target_dir"/}"
      rel="${rel#/}"
      echo "  $rel"
    done <"$list_file"
    ok "Would concatenate $count file(s)"
    return 0
  fi

  local tmp_out
  tmp_out=$(mktemp "${TMPDIR:-/tmp}/concat_out_XXXXXX") || die "$EX_CANTCREAT" "Failed to create temp output file"
  trap 'rm -f "$list_file" "$stats_file" "$tmp_out" ${LOCK_FILE:-}' EXIT INT TERM HUP

  local total_file_count
  total_file_count=$(wc -l <"$list_file" | tr -d ' ')

  local xsd_ref=""
  if [[ "$SCHEMA" -eq 1 && "$format_type" == "ai" ]]; then
    local out_base
    out_base=$(basename "$out_file")
    xsd_ref="${out_base%.*}.xsd"
  fi

  local awk_rc=0
  _run_awk "$target_dir" "$(date '+%Y-%m-%dT%H:%M:%S')" "$format_type" \
    "$list_file" "$stats_file" "$total_file_count" \
    "$xsd_ref" "0" "0" >>"$tmp_out" || awk_rc=$?

  if [[ "$awk_rc" -ne 0 ]]; then
    rm -f "$tmp_out"
    die "$EX_ERR" "Processing failed (awk exit code $awk_rc)"
  fi

  [[ ! -s "$tmp_out" ]] && {
    rm -f "$tmp_out"
    die "$EX_ERR" "No output produced — all files may have been skipped"
  }

  mv -f "$tmp_out" "$out_file" || die "$EX_CANTCREAT" "Failed to write output: $out_file"
  trap 'rm -f "$list_file" "$stats_file" ${LOCK_FILE:-}' EXIT INT TERM HUP

  if [[ "$SCHEMA" -eq 1 && "$format_type" == "ai" ]]; then
    local out_dir out_base out_name
    out_dir=$(dirname "$out_file")
    out_base=$(basename "$out_file")
    out_name="${out_base%.*}"
    generate_schema "${out_dir}/${out_name}.xsd"
  fi

  if [[ "$DEPS" -eq 1 ]]; then
    local out_dir out_base out_name
    out_dir=$(dirname "$out_file")
    out_base=$(basename "$out_file")
    out_name="${out_base%.*}"
    local deps_file
    deps_file=$(mktemp "${TMPDIR:-/tmp}/concat_deps_XXXXXX")
    scan_deps "$target_dir" "$deps_file"
    if [[ -s "$deps_file" ]]; then
      local deps_xml injected_file
      deps_xml=$(awk -F'\t' '{ printf "  <edge source=\"%s\" target=\"%s\" type=\"%s\" />\n", $1, $2, $3 }' "$deps_file")
      injected_file=$(mktemp "${TMPDIR:-/tmp}/concat_injected_XXXXXX")
      awk -v deps="$deps_xml" '
        /<\/repository_index>/ { print; print ""; print "<dependencies>"; print deps; print "</dependencies>"; print ""; next }
        { print }
      ' "$out_file" >"$injected_file"
      mv -f "$injected_file" "$out_file"
      generate_dot "$deps_file" "${out_dir}/${out_name}-deps.dot"
      ok "Dependency graph: ${out_dir}/${out_name}-deps.dot"
    else
      verbose "No dependencies found"
    fi
    rm -f "$deps_file"
  fi

  IFS='|' read -r t_files t_lines t_chars <"$stats_file" || die "$EX_ERR" "Failed to read stats"

  local size_str
  if ((t_chars >= 1048576)); then
    size_str=$(awk "BEGIN {printf \"%.1f MB\", $t_chars/1048576}")
  elif ((t_chars >= 1024)); then
    size_str=$(awk "BEGIN {printf \"%.1f KB\", $t_chars/1024}")
  else size_str="${t_chars} chars"; fi

  echo
  ok "Generated: $out_file"
  echo "Files : $t_files"
  echo "Lines : $t_lines"
  echo "Size  : $size_str"
  [[ "$SCHEMA" -eq 1 && "$format_type" == "ai" ]] && {
    local out_base
    out_base=$(basename "$out_file")
    echo "Schema: ${out_base%.*}.xsd"
  }
  echo
}

# ── Interactive Mode ────────────────────────────────────
interactive_mode() {
  check_deps 1

  echo "1) AI Context (.txt)"
  echo "2) Human Readable (.md)"
  local format_choice
  format_choice=$(ask "Choose format" "1")

  local format_type="ai" ext="txt" suffix="-ai-context"
  if [[ "$format_choice" == "2" ]]; then
    format_type="human"
    ext="md"
    suffix="-human-readable"
  fi

  echo

  local target_dir
  target_dir=$(
    command find "$PWD" -maxdepth 1 -type d -not -name '.*' 2>/dev/null |
      fzf --prompt="Directory > " --height=15 --layout=reverse --border
  )
  [[ -z "$target_dir" ]] && die "$EX_ERR" "No directory selected"
  ok "Selected: $target_dir"
  echo

  run_rg "$target_dir" | fzf -m \
    --prompt="Files > " \
    --bind "ctrl-a:select-all" \
    --height=60% --layout=reverse --border \
    --preview "head -n 50 {}" \
    --preview-window=right:60% >"$list_file"

  local file_count
  file_count=$(wc -l <"$list_file" | tr -d ' ')
  [[ "$file_count" -eq 0 ]] && die "$EX_ERR" "No files selected"
  ok "Selected $file_count files"

  local dir_name
  dir_name=$(basename "$target_dir")
  local default_out="$PWD/${dir_name}${suffix}.${ext}"
  local out_file
  out_file=$(ask "Output file" "$default_out")
  out_file="${out_file/#\~/$HOME}"

  if [[ -f "$out_file" ]]; then
    local overwrite
    overwrite=$(ask "File exists: $out_file. Overwrite? (y/n)" "n")
    [[ "${overwrite,,}" != "y" ]] && die "$EX_ERR" "Aborted"
  fi

  info "Generating..."
  validate_inputs "$target_dir" "$out_file"
  acquire_lock "$out_file"
  do_concat "$target_dir" "$out_file" "$format_type"
  release_lock
}

# ── CLI Mode ────────────────────────────────────────────
cli_mode() {
  check_deps

  local format_type="ai" ext="txt" target_dir="." out_file="" force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --ai)
      format_type="ai"
      ext="txt"
      shift
      ;;
    --human)
      format_type="human"
      ext="md"
      shift
      ;;
    -o | --output)
      [[ $# -lt 2 ]] && die "$EX_USAGE" "$1 requires a path"
      out_file="${2/#\~/$HOME}"
      shift 2
      ;;
    -q | --quiet)
      QUIET=1
      shift
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --max-size)
      [[ $# -lt 2 ]] && die "$EX_USAGE" "$1 requires a size (e.g. 100K, 5M)"
      MAX_SIZE=$(parse_size "$2")
      shift 2
      ;;
    --no-color)
      CLI_NO_COLOR=1
      _setup_colors
      shift
      ;;
    --schema)
      SCHEMA=1
      shift
      ;;
    --deps)
      DEPS=1
      shift
      ;;
    --chunk-size)
      [[ $# -lt 2 ]] && die "$EX_USAGE" "$1 requires a number"
      [[ "$2" -lt 1 ]] && die "$EX_USAGE" "Chunk size must be >= 1"
      CHUNK_SIZE="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h | --help)
      usage
      exit "$EX_OK"
      ;;
    --)
      shift
      break
      ;;
    -*) die "$EX_USAGE" "Unknown option: $1" ;;
    *)
      [[ -d "$1" ]] || die "$EX_USAGE" "Invalid argument: $1"
      target_dir="$1"
      shift
      ;;
    esac
  done

  [[ $# -gt 0 ]] && {
    [[ -d "$1" ]] || die "$EX_USAGE" "Invalid argument: $1"
    target_dir="$1"
  }

  target_dir="${target_dir/#\~/$HOME}"
  [[ ! -d "$target_dir" ]] && die "$EX_NOINPUT" "Not a directory: $target_dir"
  target_dir=$(cd "$target_dir" && pwd)

  if [[ -z "$out_file" ]]; then
    local dir_name
    dir_name=$(basename "$target_dir")
    if [[ "$format_type" == "ai" ]]; then
      out_file="$PWD/${dir_name}-ai-context.${ext}"
    else out_file="$PWD/${dir_name}-human-readable.${ext}"; fi
  fi

  [[ -f "$out_file" && "$force" -eq 0 && "$DRY_RUN" -eq 0 ]] &&
    die "$EX_CANTCREAT" "Output file already exists: $out_file (use --force to overwrite)"

  verbose "Target dir : $target_dir"
  verbose "Output file: $out_file"
  verbose "Format     : $format_type"
  verbose "Max size   : $MAX_SIZE bytes"
  verbose "Schema     : $SCHEMA"
  verbose "Deps       : $DEPS"
  verbose "Chunk size : $CHUNK_SIZE"

  # FIX: capture rg exit code instead of silently swallowing it with || true
  local rg_rc=0
  run_rg "$target_dir" >"$list_file" || rg_rc=$?

  if [[ "$rg_rc" -ne 0 ]]; then
    warn "rg exited with code $rg_rc — results may be incomplete"
  fi

  if [[ ! -s "$list_file" ]]; then
    # Give a helpful hint about what might be wrong
    local raw_count
    raw_count=$(rg --files --hidden -g '!.git/' "$target_dir" 2>/dev/null | wc -l | tr -d ' ') || raw_count=0
    if [[ "$raw_count" -gt 0 ]]; then
      die "$EX_NOINPUT" "No files found after filtering in: $target_dir (${raw_count} files exist but were excluded — check .gitignore or use --verbose)"
    else
      die "$EX_NOINPUT" "No files found in: $target_dir"
    fi
  fi

  local file_count
  file_count=$(wc -l <"$list_file" | tr -d ' ')
  verbose "Files found: $file_count"

  validate_inputs "$target_dir" "$out_file"
  [[ "$DRY_RUN" -eq 0 ]] && acquire_lock "$out_file"

  if [[ "$CHUNK_SIZE" -gt 0 ]]; then
    info "Generating chunks..."
    chunk_stream "$target_dir" "$out_file" "$format_type" "$CHUNK_SIZE"
  else
    info "Generating..."
    do_concat "$target_dir" "$out_file" "$format_type"
  fi

  [[ "$DRY_RUN" -eq 0 ]] && release_lock
}

# ── Entry ───────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
  --no-color) CLI_NO_COLOR=1 ;;
  -q | --quiet) QUIET=1 ;;
  -v | --verbose) VERBOSE=1 ;;
  esac
done

_setup_colors

if [[ $# -eq 0 ]]; then
  interactive_mode
else cli_mode "$@"; fi
