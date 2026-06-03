#!/usr/bin/env bash

# Git2AI: Pure AI Lore & Reindexing Engine (v4.2.0 - Universal)
# Fully dynamic, repo-agnostic context exporter for LLMs.

export LC_ALL=C
set +o histexpand 2>/dev/null || true

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "Error: bash 4+ required (found $BASH_VERSION)" >&2
  exit 1
fi

# Default configurations
FROM_COMMIT=""
TO_COMMIT=""
MAX_FILE_LINES=1000
MAX_DIFF_LINES=500
OUTPUT_FILE="git2ai_ai_context.txt"
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
  --max-diff-lines)
    MAX_DIFF_LINES="$2"
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
  echo "Error: $REPO_DIR is not a git repository."
  exit 1
fi

cd "$REPO_DIR"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

HISTORY_FILE="$TMP_DIR/history.xml"
FILE_EVENTS="$TMP_DIR/file_events.tsv"
TOC_FILE="$TMP_DIR/toc.tsv"

touch "$FILE_EVENTS" "$TOC_FILE"

xml_escape_attr() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//\"/&quot;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

if [ -n "$FROM_COMMIT" ] && [ -n "$TO_COMMIT" ]; then
  git rev-list --reverse --ancestry-path "$FROM_COMMIT"^.."$TO_COMMIT" >"$TMP_DIR/commits.txt" 2>/dev/null || git rev-list --reverse "$FROM_COMMIT".."$TO_COMMIT" >"$TMP_DIR/commits.txt"
elif [ -n "$FROM_COMMIT" ]; then
  git rev-list --reverse "$FROM_COMMIT"..HEAD >"$TMP_DIR/commits.txt"
elif [ -n "$TO_COMMIT" ]; then
  git rev-list --reverse "$TO_COMMIT" >"$TMP_DIR/commits.txt"
else
  git rev-list --reverse HEAD >"$TMP_DIR/commits.txt"
fi

mapfile -t COMMITS <"$TMP_DIR/commits.txt"
total_commits=${#COMMITS[@]}

if [ "$total_commits" -eq 0 ]; then
  echo "No commits found."
  exit 0
fi

echo "Processing $total_commits commits for AI Context Engine..."

# ==========================================
# DYNAMIC FILTERS (Repo-Agnostic)
# ==========================================
is_ignored() {
  local file=$1
  local ignore_dirs=(
    node_modules vendor build dist out coverage .git .svn .hg .bzr
    .idea .vscode .vs .eclipse .settings .DS_Store .docker .terraform
    .direnv .local .config .nuget .cargo .rustup .npm .yarn .pnpm-store
    .pnp bower_components .cache .parcel-cache .turbo .vercel .netlify
    __pycache__ .mypy_cache .pytest_cache .ruff_cache .venv venv env .tox .nox .eggs site-packages .ipynb_checkpoints
    .gradle .mvn .classpath .bundle target
  )
  for pat in "${ignore_dirs[@]}"; do
    if [[ "$file" == "$pat"/* || "$file" == *"/$pat/"* || "$file" == *"/$pat" || "$file" == "$pat" ]]; then
      return 0
    fi
  done
  for pat in "${CUSTOM_IGNORES[@]}"; do
    if [[ "$file" == *"$pat"* ]]; then return 0; fi
  done
  return 1
}

is_binary() {
  local file=$1
  case "$file" in
  *.png | *.jpg | *.jpeg | *.gif | *.pdf | *.zip | *.tar | *.gz | *.exe | *.dll | *.woff | *.woff2 | *.ttf | *.eot | *.mp3 | *.mp4 | *.mov | *.avi | *.bin | *.so | *.dylib | *.class | *.pyc | *.pyo | *.o | *.obj | *.a | *.lib | *.wasm | *.keystore | *.p12 | *.jks | *.sqlite | *.db | *.ico | *.svg | *.webp | *.bmp | *.tiff | *.mpg | *.mpeg | *.flv | *.ogg | *.wav | *.flac | *.jar | *.war | *.ear | *.apk | *.aab | *.app | *.dmg | *.iso | *.img | *.7z | *.rar | *.lockb | *.pem | *.crt | *.key) return 0 ;;
  esac
  return 1
}

is_lockfile() {
  local file=$1
  case "$file" in
  package-lock.json | yarn.lock | pnpm-lock.yaml | composer.lock | Cargo.lock | Gemfile.lock | poetry.lock | Pipfile.lock | lazy-lock.json | bun.lockb) return 0 ;;
  esac
  return 1
}

get_lang_fence() {
  local file="$1"
  case "$file" in
  *.js | *.jsx | *.mjs | *.cjs) echo "javascript" ;; *.ts | *.tsx | *.mts | *.cts) echo "typescript" ;;
  *.py) echo "python" ;; *.rb) echo "ruby" ;; *.java) echo "java" ;; *.c | *.h) echo "c" ;;
  *.cpp | *.hpp | *.cc | *.cxx) echo "cpp" ;; *.cs) echo "csharp" ;; *.go) echo "go" ;; *.rs) echo "rust" ;;
  *.php) echo "php" ;; *.swift) echo "swift" ;; *.kt | *.kts) echo "kotlin" ;; *.sh | *.bash | *.zsh) echo "bash" ;;
  *.html | *.htm) echo "html" ;; *.css | *.scss | *.sass | *.less) echo "css" ;; *.json) echo "json" ;;
  *.xml) echo "xml" ;; *.yml | *.yaml) echo "yaml" ;; *.md | *.markdown) echo "markdown" ;; *.sql) echo "sql" ;;
  *.ejs) echo "ejs" ;; *.vue) echo "vue" ;; *.svelte) echo "svelte" ;; *.lua) echo "lua" ;; *) echo "text" ;;
  esac
}

declare -A file_to_id
file_id_counter=0

get_file_id() {
  local file=$1 status=$2 prev_file=$3
  if [ "$status" == "R" ] && [ -n "${file_to_id[$prev_file]}" ]; then
    local id="${file_to_id[$prev_file]}"
    file_to_id["$file"]="$id"
    _FILE_ID_RESULT="$id"
  elif [ "$status" == "A" ] || [ -z "${file_to_id[$file]}" ]; then
    file_id_counter=$((file_id_counter + 1))
    local id="F$file_id_counter"
    file_to_id["$file"]="$id"
    _FILE_ID_RESULT="$id"
  else
    _FILE_ID_RESULT="${file_to_id[$file]}"
  fi
}

commit_num=0
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

for ((i = 0; i < total_commits; i++)); do
  commit_hash=${COMMITS[$i]}
  commit_num=$((i + 1))

  if ((commit_num % 50 == 0)) || ((commit_num == total_commits)); then
    echo "Processed $commit_num / $total_commits commits..."
  fi

  meta=$(git show -s --format="%H%n%P%n%aI%n%an" "$commit_hash")
  {
    read -r hash
    read -r parents
    read -r date
    read -r author
  } <<<"$meta"
  xml_author=$(xml_escape_attr "$author")

  msg=$(git show -s --format="%B" "$commit_hash")
  msg="${msg//$'\r'/}"
  msg_first_line="${msg%%$'\n'*}"

  printf '%s\t%s\n' "$commit_num" "$msg_first_line" >>"$TOC_FILE"

  printf '<commit num="%s" hash="%s" author="%s" date="%s">\n' "$commit_num" "$commit_hash" "$xml_author" "$date" >>"$HISTORY_FILE"
  safe_msg="${msg//]]>/] ]>}"
  printf '  <message><![CDATA[%s]]></message>\n' "$safe_msg" >>"$HISTORY_FILE"
  printf '  <parents>%s</parents>\n' "$parents" >>"$HISTORY_FILE"

  main_parent=${parents%% *}
  if [ -z "$main_parent" ]; then main_parent="$EMPTY_TREE"; fi

  git diff-tree --no-commit-id -r -M -C --name-status "$main_parent" "$commit_hash" >"$TMP_DIR/status.txt"

  while IFS=$'\t' read -r status f1 f2; do
    [ -z "$status" ] && continue
    target_file="${f2:-$f1}"
    if is_ignored "$target_file" || is_binary "$target_file"; then continue; fi

    if [ "$status" == "A" ]; then
      if git cat-file -e "$main_parent:$f1" 2>/dev/null; then status="M"; fi
    fi

    get_file_id "$target_file" "$status" "$f1"
    local_id="$_FILE_ID_RESULT"
    fence=$(get_lang_fence "$f1")

    xml_f1=$(xml_escape_attr "$f1")
    xml_f2=$(xml_escape_attr "$f2")

    case "$status" in
    A)
      printf '  <file path="%s" action="Created" id="%s">\n' "$xml_f1" "$local_id" >>"$HISTORY_FILE"
      if is_lockfile "$f1"; then
        printf '    <content omitted="true" reason="lockfile" />\n' >>"$HISTORY_FILE"
      else
        git show "$commit_hash:$f1" 2>/dev/null >"$TMP_DIR/current_file.txt"
        line_count=$(awk 'END{print NR}' "$TMP_DIR/current_file.txt")
        printf '    <content lang="%s" lines="%s">\n' "$fence" "$line_count" >>"$HISTORY_FILE"
        if [ "$line_count" -gt "$MAX_FILE_LINES" ]; then
          head -n "$MAX_FILE_LINES" "$TMP_DIR/current_file.txt" >>"$HISTORY_FILE"
          printf '... [TRUNCATED] ...\n' >>"$HISTORY_FILE"
        else
          cat "$TMP_DIR/current_file.txt" >>"$HISTORY_FILE"
        fi
        printf '    </content>\n' >>"$HISTORY_FILE"
      fi
      printf '  </file>\n' >>"$HISTORY_FILE"
      printf '%s\t%s\t%s\t%s\t%s\n' "$f1" "Created" "$commit_num" "$commit_hash" "$local_id" >>"$FILE_EVENTS"
      ;;
    M)
      printf '  <file path="%s" action="Modified" id="%s">\n' "$xml_f1" "$local_id" >>"$HISTORY_FILE"
      if is_lockfile "$f1"; then
        printf '    <diff omitted="true" reason="lockfile" />\n' >>"$HISTORY_FILE"
      else
        git diff "$main_parent" "$commit_hash" -- "$f1" 2>/dev/null | grep -v -E '^(diff --git|index |--- a/|\+\+\+ b/)' >"$TMP_DIR/current_diff.txt"
        diff_lines=$(awk 'END{print NR}' "$TMP_DIR/current_diff.txt")
        printf '    <diff lines="%s">\n' "$diff_lines" >>"$HISTORY_FILE"
        if [ "$diff_lines" -gt "$MAX_DIFF_LINES" ]; then
          head -n "$MAX_DIFF_LINES" "$TMP_DIR/current_diff.txt" >>"$HISTORY_FILE"
          printf '... [DIFF TRUNCATED] ...\n' >>"$HISTORY_FILE"
        else
          cat "$TMP_DIR/current_diff.txt" >>"$HISTORY_FILE"
        fi
        printf '    </diff>\n' >>"$HISTORY_FILE"
      fi
      printf '  </file>\n' >>"$HISTORY_FILE"
      printf '%s\t%s\t%s\t%s\t%s\n' "$f1" "Modified" "$commit_num" "$commit_hash" "$local_id" >>"$FILE_EVENTS"
      ;;
    D)
      printf '  <file path="%s" action="Deleted" id="%s"><deleted /></file>\n' "$xml_f1" "$local_id" >>"$HISTORY_FILE"
      printf '%s\t%s\t%s\t%s\t%s\n' "$f1" "Deleted" "$commit_num" "$commit_hash" "$local_id" >>"$FILE_EVENTS"
      ;;
    R*)
      printf '  <file path="%s" action="Renamed" id="%s"><renamed from="%s" to="%s" /></file>\n' "$xml_f1" "$local_id" "$xml_f1" "$xml_f2" >>"$HISTORY_FILE"
      printf '%s\t%s\t%s\t%s\t%s\n' "$f1" "Renamed" "$commit_num" "$commit_hash" "$local_id" >>"$FILE_EVENTS"
      printf '%s\t%s\t%s\t%s\t%s\n' "$f2" "Renamed_From" "$commit_num" "$commit_hash" "$local_id" >>"$FILE_EVENTS"
      ;;
    esac
  done <"$TMP_DIR/status.txt"

  printf '</commit>\n' >>"$HISTORY_FILE"
done

# ==========================================
# POST-PROCESSING: AI LORE & MAP GENERATION
# ==========================================
lang_target_commit="${COMMITS[$((total_commits - 1))]:-HEAD}"

out() { printf '%s\n' "$1" >>"$2"; }

out "<repository_map>" "$TMP_DIR/map.xml"

out "  <evolutionary_milestones>" "$TMP_DIR/map.xml"
awk -F'\t' '{
  msg = tolower($2)
  if (msg ~ /initial/ || msg ~ /setup/ || msg ~ /refactor/ || msg ~ /feat:/ || msg ~ /architecture/ || msg ~ /mvc/ || msg ~ /auth/ || msg ~ /database/ || msg ~ /api/) {
    print "    <milestone commit=\"" $1 "\">" $2 "</milestone>"
  }
}' "$TOC_FILE" >>"$TMP_DIR/map.xml"
out "  </evolutionary_milestones>" "$TMP_DIR/map.xml"

out "  <architecture>" "$TMP_DIR/map.xml"
out "    <![CDATA[" "$TMP_DIR/map.xml"
git ls-tree -r --name-only "$lang_target_commit" | grep -v -E '(\.png|\.jpg|\.gif|\.pdf|\.zip|node_modules|vendor|package-lock\.json|yarn\.lock)' | sort | awk -F'/' '{p = ""; for (i=1; i<NF; i++) { p = p $i "/"; if (!(p in seen)) { indent = ""; for (j=1; j<i; j++) indent = indent "    "; print indent "+-- " $i "/"; seen[p] = 1 } } indent = ""; for (j=1; j<NF; j++) indent = indent "    "; print indent "|-- " $NF}' >>"$TMP_DIR/map.xml"
out "    ]]>" "$TMP_DIR/map.xml"
out "  </architecture>" "$TMP_DIR/map.xml"

out "  <file_lineage>" "$TMP_DIR/map.xml"
sort -t$'\t' -k5,5 -k3,3n "$FILE_EVENTS" | awk -F'\t' '{id=$5; file=$1; status=$2; commit=$3; if (id != last_id) {if (last_id != "") {printf "    <file id=\"%s\" path=\"%s\" created=\"%s\" modified=\"%s\" deleted=\"%s\" />\n", last_id, last_file, created, modified, deleted;} last_id=id; last_file=file; created=""; modified=""; deleted="";} if (status == "Created") created=commit; else if (status == "Modified") modified = (modified == "" ? commit : modified "," commit); else if (status == "Deleted") deleted=commit; else if (status == "Renamed") last_file=file;} END {if (last_id != "") {printf "    <file id=\"%s\" path=\"%s\" created=\"%s\" modified=\"%s\" deleted=\"%s\" />\n", last_id, last_file, created, modified, deleted;}}' >>"$TMP_DIR/map.xml"
out "  </file_lineage>" "$TMP_DIR/map.xml"

out "</repository_map>" "$TMP_DIR/map.xml"

# ==========================================
# POST-PROCESSING: CURRENT STATE SNAPSHOT (THE UNIVERSAL REINDEXER)
# ==========================================
out "<current_state>" "$TMP_DIR/snapshot.xml"
out "  <note>Full code of core source files at the latest commit. Use this as the absolute ground truth for writing new features or refactoring.</note>" "$TMP_DIR/snapshot.xml"

# Universal Exclusion Regex for Directories & Lockfiles
EXCLUDE_DIRS_AND_LOCKS='(node_modules/|vendor/|target/|build/|dist/|out/|\.next/|\.nuxt/|\.output/|\.svelte-kit/|\.astro/|\.docusaurus/|\.vuepress/|coverage/|\.nyc_output/|__pycache__/|\.mypy_cache/|\.pytest_cache/|\.ruff_cache/|\.venv/|venv/|env/|\.env/|\.tox/|\.nox/|\.eggs/|site-packages/|\.ipynb_checkpoints/|\.gradle/|\.mvn/|\.classpath/|\.settings/|\.bundle/|\.idea/|\.vscode/|\.vs/|\.eclipse/|\.DS_Store|\.Trash/|\.docker/|\.terraform/|\.direnv/|\.local/|\.config/|\.nuget/|\.cargo/|\.rustup/|\.git/|\.svn/|\.hg/|\.bzr/|\.npm/|\.yarn/|\.pnpm-store/|\.pnp|bower_components/|\.cache/|\.parcel-cache/|\.turbo/|\.vercel/|\.netlify/|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb|Gemfile\.lock|Cargo\.lock|poetry\.lock|Pipfile\.lock|composer\.lock|uv\.lock|pdm\.lock|lazy-lock\.json)'

# Universal Exclusion Regex for Binaries, Media, and Minified Files
EXCLUDE_BINARIES_AND_MEDIA='(\.min\.|\.map$|\.png$|\.jpg$|\.jpeg$|\.gif$|\.svg$|\.webp$|\.avif$|\.bmp$|\.ico$|\.tiff$|\.mp3$|\.mp4$|\.wav$|\.flac$|\.ogg$|\.avi$|\.mov$|\.zip$|\.tar$|\.gz$|\.bz2$|\.xz$|\.7z$|\.rar$|\.class$|\.o$|\.obj$|\.pyc$|\.pyo$|\.exe$|\.dll$|\.so$|\.dylib$|\.a$|\.lib$|\.wasm$|\.keystore$|\.p12$|\.jks$|\.sqlite$|\.db$|\.woff$|\.woff2$|\.ttf$|\.eot$|\.otf$|\.pdf$|\.doc$|\.docx$|\.xls$|\.xlsx$|\.ppt$|\.pptx$)'

# Grab ALL tracked text files, aggressively filtering out known junk.
git ls-tree -r --name-only "$lang_target_commit" |
  grep -v -E "$EXCLUDE_DIRS_AND_LOCKS" |
  grep -v -E "$EXCLUDE_BINARIES_AND_MEDIA" |
  while read -r file; do

    xml_file=$(xml_escape_attr "$file")
    fence=$(get_lang_fence "$file")

    git show "$lang_target_commit:$file" 2>/dev/null >"$TMP_DIR/snapshot_file.txt"

    # Skip if git show failed (e.g., submodule or weird gitlink) or file is empty
    [ ! -s "$TMP_DIR/snapshot_file.txt" ] && continue

    line_count=$(awk 'END{print NR}' "$TMP_DIR/snapshot_file.txt")

    out "  <file path=\"$xml_file\" lang=\"$fence\" lines=\"$line_count\">" "$TMP_DIR/snapshot.xml"
    out "    <![CDATA[" "$TMP_DIR/snapshot.xml"

    if [ "$line_count" -gt "$MAX_FILE_LINES" ]; then
      head -n "$MAX_FILE_LINES" "$TMP_DIR/snapshot_file.txt" >>"$TMP_DIR/snapshot.xml"
      printf '\n... [TRUNCATED FOR CONTEXT LIMIT] ...\n' >>"$TMP_DIR/snapshot.xml"
    else
      cat "$TMP_DIR/snapshot_file.txt" >>"$TMP_DIR/snapshot.xml"
    fi

    out "    ]]>" "$TMP_DIR/snapshot.xml"
    out "  </file>" "$TMP_DIR/snapshot.xml"
  done
out "</current_state>" "$TMP_DIR/snapshot.xml"

# ==========================================
# FINAL ASSEMBLY
# ==========================================
printf '<?xml version="1.0" encoding="UTF-8"?>\n<git2ai_export mode="PURE_AI_LORE_AND_REINDEX" total_commits="%s" repo="%s">\n' "$total_commits" "$(basename "$(git rev-parse --show-toplevel)")" >"$OUTPUT_FILE"
cat "$TMP_DIR/map.xml" >>"$OUTPUT_FILE"
printf '<history>\n' >>"$OUTPUT_FILE"
cat "$HISTORY_FILE" >>"$OUTPUT_FILE"
printf '</history>\n' >>"$OUTPUT_FILE"
cat "$TMP_DIR/snapshot.xml" >>"$OUTPUT_FILE"
printf '</git2ai_export>\n' >>"$OUTPUT_FILE"

echo "Export complete: $OUTPUT_FILE"
