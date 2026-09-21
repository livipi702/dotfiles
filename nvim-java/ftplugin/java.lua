-- nvim-jdtls ftplugin config (see :help jdtls and nvim-jdtls README).
-- Must NOT enable jdtls via vim.lsp.enable (see lua/plugins/lsp.lua).
-- Executed on every FileType=java event.
local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
  return
end

-- Root: gradle/maven/git. Single DSA files fall back to the file's dir.
local root_dir = vim.fs.root(0, { "gradlew", "mvnw", "pom.xml", "build.gradle", ".git" })
if not root_dir then
  root_dir = vim.fn.expand("%:p:h")
end

-- Dedicated -data workspace per project (avoids reindex + corruption).
local project_name = vim.fs.basename(root_dir)
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

-- Bundles for debugging + JUnit (installed via mason, isolated to nvim-java data dir).
local mason_share = vim.fn.stdpath("data") .. "/mason/packages"
local bundles = vim.fn.glob(mason_share .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar", false, true)
local java_test_bundles = vim.fn.glob(mason_share .. "/java-test/extension/server/*.jar", false, true)
local excluded = {
  "com.microsoft.java.test.runner-jar-with-dependencies.jar",
  "jacocoagent.jar",
}
for _, jar in ipairs(java_test_bundles) do
  local fname = vim.fn.fnamemodify(jar, ":t")
  if fname ~= "" and not vim.tbl_contains(excluded, fname) then
    table.insert(bundles, jar)
  end
end

local config = {
  name = "jdtls",
  cmd = { "jdtls", "-data", workspace_dir },
  root_dir = root_dir,
  settings = {
    java = {},
  },
  init_options = {
    bundles = bundles,
  },
}

-- blink.cmp capabilities (same pattern as lua/plugins/lsp.lua).
local blink_ok, blink = pcall(require, "blink.cmp")
if blink_ok then
  config.capabilities = blink.get_lsp_capabilities()
end

jdtls.start_or_attach(config)

-- Buffer-local Java extras (official nvim-jdtls API).
local map = function(mode, keys, fn, desc)
  vim.keymap.set(mode, keys, fn, { buffer = true, desc = "Java: " .. desc })
end
map("n", "<A-o>", function()
  require("jdtls").organize_imports()
end, "Organize imports")
map("n", "crv", function()
  require("jdtls").extract_variable()
end, "Extract variable")
map("v", "crv", function()
  require("jdtls").extract_variable(true)
end, "Extract variable")
map("n", "crc", function()
  require("jdtls").extract_constant()
end, "Extract constant")
map("v", "crc", function()
  require("jdtls").extract_constant(true)
end, "Extract constant")
map("v", "crm", function()
  require("jdtls").extract_method(true)
end, "Extract method")
-- JUnit via bundles (needs Maven/Gradle project; idle for single DSA files).
map("n", "<leader>df", function()
  require("jdtls").test_class()
end, "Test class")
map("n", "<leader>dn", function()
  require("jdtls").test_nearest_method()
end, "Test nearest")
-- Single-file run for DSA (javac + java, no build tool needed).
map("n", "<leader>r", function()
  local file = vim.fn.expand("%:p")
  local dir = vim.fn.expand("%:p:h")
  local classname = vim.fn.expand("%:t:r")
  local cmd = string.format("javac -d %s %s && java -cp %s %s", vim.fn.shellescape(dir), vim.fn.shellescape(file), vim.fn.shellescape(dir), classname)
  vim.cmd("split | terminal " .. cmd)
end, "Run single file")
