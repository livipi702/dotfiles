-- lua_ls for editing our own config: LuaJIT runtime, vim global known,
-- full Neovim runtime library attached.
return {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
    },
  },
}
