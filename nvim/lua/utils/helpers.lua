local M = {}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║           HELPERS                      ║
-- ╚══════════════════════════════════════════════════════════════╝

local function detect_os()
  if vim.fn.has("mac") == 1 then
    return "mac"
  end
  if vim.fn.has("win32") == 1 then
    return "win"
  end
  return "linux"
end

local CURRENT_OS = detect_os()

-- ══════════════════════════════════════════════════════════════
-- FILESYSTEM
-- ══════════════════════════════════════════════════════════════

local function has_cmd(cmd)
  return vim.fn.executable(cmd) == 1
end

local function has_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

local function temp_base()
  if CURRENT_OS == "win" then
    return (vim.env.TEMP or vim.env.TMP or "C:\\Temp") .. "\\nvim_run"
  end
  return "/tmp/nvim_run"
end

local _home = vim.env.HOME or vim.fn.expand("~")
local function home_dir()
  return _home
end

-- ══════════════════════════════════════════════════════════════
-- CACHE
-- ══════════════════════════════════════════════════════════════

local _cache = {}

local function cached(key_fn, compute_fn)
  return function(...)
    local key = key_fn(...)
    if _cache[key] ~= nil then
      return _cache[key]
    end
    local result = compute_fn(...)
    if result ~= nil then
      _cache[key] = result
    end
    return result
  end
end

local function cache_invalidate()
  _cache = {}
end

-- ══════════════════════════════════════════════════════════════
-- RUNTIME LOOKUPS
-- ══════════════════════════════════════════════════════════════

local get_python = cached(
  function()
    return "python:" .. vim.fn.getcwd()
  end,
  function()
    local venv_patterns
    if CURRENT_OS == "win" then
      venv_patterns = {
        "venv/Scripts/python.exe",
        ".venv/Scripts/python.exe",
        "env/Scripts/python.exe",
      }
    else
      venv_patterns = {
        "venv/bin/python",
        ".venv/bin/python",
        "env/bin/python",
      }
    end
    local cwd = vim.fn.getcwd()
    for _, pat in ipairs(venv_patterns) do
      local path = cwd .. "/" .. pat
      if has_cmd(path) then
        return path
      end
    end
    if has_cmd("python3") then
      return "python3"
    end
    return "python"
  end
)

local function safe_hash(str)
  local ok, result = pcall(vim.fn.sha256, str)
  if ok and result then
    return result:sub(1, 8)
  end
  local h = 0
  for i = 1, #str do
    h = ((h % 0x0FFFFFFF) * 31 + string.byte(str, i)) % 0x7FFFFFFF
  end
  return string.format("%08x", h)
end

-- ══════════════════════════════════════════════════════════════
-- PROJECT MARKERS
-- ══════════════════════════════════════════════════════════════

local PROJECT_MARKERS = {
  ".git", "package.json", "tsconfig.json", "go.mod", "Cargo.toml",
  "pyproject.toml", "pom.xml", "build.gradle", "build.gradle.kts",
  "CMakeLists.txt", "Makefile",
}

-- ══════════════════════════════════════════════════════════════
-- PROJECT ROOT LOOKUP
-- ══════════════════════════════════════════════════════════════
local function find_project_root(markers, start_path)
  markers = markers or PROJECT_MARKERS
  start_path = start_path or vim.fn.expand("%:p:h")
  if not start_path or start_path == "" then
    start_path = vim.fn.getcwd()
  end

  local stat = vim.uv.fs_stat(start_path)
  if stat and stat.type == "file" then
    start_path = vim.fs.dirname(start_path) or vim.fn.getcwd()
  end

  local found = vim.fs.find(markers, {
    upward = true,
    path = start_path,
    stop = home_dir(),
  })
  if found and #found > 0 then
    return vim.fn.fnamemodify(found[1], ":h")
  end
  return vim.fn.getcwd()
end

local function current_file_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" then
    return vim.fn.fnamemodify(name, ":p:h")
  end
  return vim.fn.getcwd()
end

local function project_root_or_cwd(start_path, markers)
  return find_project_root(markers, start_path or current_file_dir())
end

local function is_big_file(bufnr, max_size)
  bufnr = bufnr or 0
  max_size = max_size or (1024 * 1024)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end
  local stat = vim.uv.fs_stat(name)
  return stat ~= nil and stat.type == "file" and stat.size > max_size
end

-- ══════════════════════════════════════════════════════════════
-- TYPESCRIPT RUNTIME
-- ══════════════════════════════════════════════════════════════
local resolve_ts_cmd = cached(
  function()
    return "tscmd:" .. vim.fn.getcwd() .. ":" .. vim.fn.expand("%:p")
  end,
  function()
    if has_cmd("deno") then
      return "deno run"
    end
    if has_cmd("bun") then
      return "bun run"
    end
    if has_cmd("tsx") then
      return "tsx"
    end
    if has_cmd("ts-node") then
      return "ts-node"
    end

    local current_file_dir = vim.fn.expand("%:p:h")
    local root = find_project_root({ "package.json", "tsconfig.json" }, current_file_dir)

    local tsx_path, tsnode_path
    if CURRENT_OS == "win" then
      tsx_path = root .. "\\node_modules\\.bin\\tsx.cmd"
      tsnode_path = root .. "\\node_modules\\.bin\\ts-node.cmd"
    else
      tsx_path = root .. "/node_modules/.bin/tsx"
      tsnode_path = root .. "/node_modules/.bin/ts-node"
    end
    if has_file(tsx_path) then
      return vim.fn.shellescape(tsx_path)
    end
    if has_file(tsnode_path) then
      return vim.fn.shellescape(tsnode_path)
    end
    vim.notify(
      "No TS runtime found (checked: deno, bun, tsx, ts-node, local node_modules)",
      vim.log.levels.WARN
    )
    return nil
  end
)

local function java_info(f)
  local classname = vim.fn.fnamemodify(f, ":t:r")
  local srcdir = vim.fn.fnamemodify(f, ":h")

  local lines
  local bufnr = vim.fn.bufnr(f)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, 30, false)
  else
    if not has_file(f) then
      return srcdir, classname
    end
    local ok
    ok, lines = pcall(vim.fn.readfile, f, "", 30)
    if not ok or not lines then
      return srcdir, classname
    end
  end

  local pkg = nil
  for _, line in ipairs(lines) do
    local p = line:match("^%s*package%s+([%w%.]+)%s*;")
    if p then
      pkg = p
      break
    end
  end

  local fqcn = pkg and (pkg .. "." .. classname) or classname

  if pkg then
    local depth = select(2, pkg:gsub("%.", "")) + 1
    local root = srcdir
    for _ = 1, depth do
      local parent = vim.fn.fnamemodify(root, ":h")
      if parent == root then break end
      root = parent
    end
    srcdir = root
  end

  return srcdir, fqcn
end

local function make_temp_out(f, prefix)
  local dir = vim.fn.fnamemodify(f, ":h")
  local name = vim.fn.fnamemodify(f, ":t:r")
  local hash = safe_hash(dir)
  local tmp_dir = temp_base()
  vim.fn.mkdir(tmp_dir, "p")
  local suffix = ""
  if CURRENT_OS == "win" then
    suffix = ".exe"
  end
  if prefix then
    return ("%s/%s%s_%s%s"):format(tmp_dir, prefix, name, hash, suffix)
  end
  return ("%s/%s_%s%s"):format(tmp_dir, name, hash, suffix)
end

local function java_root_from_class(class_path, fqcn)
  local pkg_depth = select(2, fqcn:gsub("%.", ""))
  local root = vim.fn.fnamemodify(class_path, ":h")
  for _ = 1, pkg_depth do
    root = vim.fn.fnamemodify(root, ":h")
  end
  return root
end

local get_browser_opener = cached(
  function() return "browser:opener" end,
  function()
    if CURRENT_OS == "mac" then
      return "open"
    end
    if CURRENT_OS == "win" then
      return "start"
    end
    if has_cmd("xdg-open") then
      return "xdg-open"
    end
    if has_cmd("wslview") then
      return "wslview"
    end
    if has_cmd("open") then
      return "open"
    end
    return nil
  end
)

-- ══════════════════════════════════════════════════════════════
-- LANGUAGE HELPERS
-- ══════════════════════════════════════════════════════════════

local function browser_run(f)
  local opener = get_browser_opener()
  if not opener then
    vim.notify("No browser opener found (tried xdg-open, wslview, open)", vim.log.levels.WARN)
    return nil
  end
  return opener .. " " .. vim.fn.shellescape(f)
end

-- ══════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════

local function check_deps(deps)
  if not deps then
    return true
  end
  for _, bin in ipairs(deps) do
    if not has_cmd(bin) then
      vim.notify(("Missing: '%s' not found in PATH"):format(bin), vim.log.levels.ERROR)
      return false
    end
  end
  return true
end

local function find_project(r)
  if not r or not r.project then
    return nil, nil
  end
  for _, p in ipairs(r.project) do
    local found
    if type(p.marker) == "function" then
      if p.marker(vim.fn.expand("%:t")) then
        found = { vim.fn.expand("%:p:h") }
      end
    elseif type(p.marker) == "string" then
      found = vim.fs.find(p.marker, {
        upward = true,
        path = vim.fn.expand("%:p:h"),
        stop = home_dir(),
      })
    end
    if found and #found > 0 then
      return vim.fn.fnamemodify(found[1], ":h"), p
    end
  end
  return nil, nil
end

local function resolve_action(action)
  if type(action) == "function" then
    return action()
  end
  return action
end

local function append_input_redirect(cmd)
  if not cmd then
    return nil
  end
  local source_dir = vim.fn.expand("%:p:h")
  local input_path = source_dir .. "/input.txt"
  if not has_file(input_path) then
    vim.notify("input.txt not found in " .. source_dir, vim.log.levels.WARN)
    return nil
  end
  return cmd .. " < " .. vim.fn.shellescape(vim.fn.fnamemodify(input_path, ":p"))
end

local function get_jdtls_bundles()
  local bundles = {}
  local mason_path = vim.fn.stdpath("data") .. "/mason/packages"

  local debug_jars =
    vim.fn.glob(mason_path .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar", false, true)
  if type(debug_jars) == "table" then
    vim.list_extend(bundles, debug_jars)
  end

  local test_jars = vim.fn.glob(mason_path .. "/java-test/extension/server/*.jar", false, true)
  if type(test_jars) == "table" then
    for _, jar in ipairs(test_jars) do
      if not vim.endswith(jar, "com.microsoft.java.test.runner-jar-with-dependencies.jar") then
        bundles[#bundles + 1] = jar
      end
    end
  end

  return bundles
end


-- ══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════════════════════

M.CURRENT_OS = CURRENT_OS
M.has_cmd = has_cmd
M.has_file = has_file
M.is_dir = is_dir
M.temp_base = temp_base
M.home_dir = home_dir
M.cached = cached
M.cache_invalidate = cache_invalidate
M.get_python = get_python
M.safe_hash = safe_hash
M.PROJECT_MARKERS = PROJECT_MARKERS
M.find_project_root = find_project_root
M.current_file_dir = current_file_dir
M.project_root_or_cwd = project_root_or_cwd
M.is_big_file = is_big_file
M.resolve_ts_cmd = resolve_ts_cmd
M.java_info = java_info
M.make_temp_out = make_temp_out
M.java_root_from_class = java_root_from_class
M.get_browser_opener = get_browser_opener
M.browser_run = browser_run
M.check_deps = check_deps
M.find_project = find_project
M.resolve_action = resolve_action
M.append_input_redirect = append_input_redirect
M.get_jdtls_bundles = get_jdtls_bundles

return M
