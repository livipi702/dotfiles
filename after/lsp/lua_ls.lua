-- lua_ls for editing our own config: LuaJIT runtime, vim global known,
-- full Neovim runtime library attached.
return {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = {
          vim.env.VIMRUNTIME,
          vim.fn.stdpath("config"),
          vim.fn.stdpath("data") .. "/lazy",
        },
        checkThirdParty = false,
      },
    },
  },
}
