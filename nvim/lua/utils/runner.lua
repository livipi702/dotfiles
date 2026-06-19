
local helpers = require("utils.helpers")
local append_input_redirect = helpers.append_input_redirect
local project_root_or_cwd = helpers.project_root_or_cwd
local CURRENT_OS = helpers.CURRENT_OS

local lang = require("utils.lang-config")
local get_lang_cfg = lang.get_lang_cfg
local check_deps = helpers.check_deps
local find_project = helpers.find_project
local resolve_action = helpers.resolve_action

local M = {}

-- ═══════════════════════════════════════════════════════════════
-- JOB MANAGER
-- ═══════════════════════════════════════════════════════════════
local job_manager = {
  active = nil,
  job_counter = 0,
  pids = {},
}

local function kill_pid(pid)
  if not pid or pid <= 0 then
    return
  end
  if vim.fn.has("win32") == 1 then
    vim.system({ "taskkill", "/PID", tostring(pid), "/T", "/F" }, { detach = true })
  else
    vim.system({ "kill", "-9", tostring(pid) }, { detach = true })
  end
end

function job_manager:cancel()
  if self.active then
    local job_data = self.active

    job_data.cancelled = true
    self.active = nil

    if job_data.id and job_data.id > 0 then
      pcall(vim.fn.jobstop, job_data.id)

      vim.defer_fn(function()
        local pid = job_data.pid
        pcall(function()
          local current_pid = vim.fn.jobpid(job_data.id)
          if current_pid and current_pid > 0 then
            pid = current_pid
          end
        end)
        if pid and pid > 0 then
          kill_pid(pid)
        end
      end, 500)
    end

    vim.notify("Job cancelled", vim.log.levels.INFO)
  end
end

function job_manager:is_running(cmd)
  if not self.active then
    return false
  end
  local active_cmd = self.active.cmd and self.active.cmd:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local new_cmd = cmd and cmd:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return active_cmd == new_cmd
end

function job_manager:compile(cmd, cwd, on_success, timeout_ms)
  if self:is_running(cmd) then
    vim.notify("Same build already in progress", vim.log.levels.INFO)
    return
  end

  self:cancel()

  self.job_counter = self.job_counter + 1
  local job_data = {
    id = nil,
    counter = self.job_counter,
    cancelled = false,
    cmd = cmd,
    start_time = vim.uv.now(),
  }

  local output = {}
  local job_cmd
  if CURRENT_OS == "win" then
    local shell = vim.o.shell:lower()
    if shell:match("powershell") or shell:match("pwsh") then
      job_cmd = { vim.o.shell, "-NoLogo", "-NoProfile", "-Command", cmd }
    elseif shell:match("cmd") then
      job_cmd = { vim.o.shell, "/c", cmd }
    else
      job_cmd = { vim.o.shell, vim.o.shellcmdflag, cmd }
    end
  else
    job_cmd = { vim.o.shell, vim.o.shellcmdflag, cmd }
  end

  local job_id = vim.fn.jobstart(job_cmd, {
    cwd = cwd or vim.fn.getcwd(),
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then
            output[#output + 1] = l
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then
            output[#output + 1] = l
          end
        end
      end
    end,
    on_exit = function(exit_id, code)
      vim.schedule(function()
        self.pids[job_data.counter] = nil

        if not self.active or self.active.counter ~= job_data.counter then
          return
        end

        if job_data.cancelled then
          self.active = nil
          return
        end

        self.active = nil
        if code ~= 0 then
          vim.fn.setqflist({}, " ", { title = "Build", lines = output })
          vim.cmd("botright copen")
          vim.notify("Build failed (exit " .. code .. ")", vim.log.levels.ERROR)
        else
          vim.fn.setqflist({}, " ", { title = "Build", lines = {} })
          vim.cmd("cclose")
          vim.notify("Build succeeded", vim.log.levels.INFO)
          if on_success then
            on_success()
          end
        end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start build job", vim.log.levels.ERROR)
    return
  end

  job_data.id = job_id
  self.active = job_data

  pcall(function()
    local pid = vim.fn.jobpid(job_id)
    if pid and pid > 0 then
      self.pids[job_data.counter] = pid
      job_data.pid = pid
    end
  end)

  if timeout_ms and timeout_ms > 0 then
    vim.defer_fn(function()
      if self.active and self.active.counter == job_data.counter and not job_data.cancelled then
        self:cancel()
        vim.notify("Build timed out after " .. (timeout_ms / 1000) .. "s", vim.log.levels.WARN)
      end
    end, timeout_ms)
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("runner_cleanup", { clear = true }),
  callback = function()
    job_manager:cancel()
    for _, pid in pairs(job_manager.pids) do
      pcall(kill_pid, pid)
    end
  end,
})

-- ═══════════════════════════════════════════════════════════════
-- PROJECT TERMINAL MANAGEMENT
-- ═══════════════════════════════════════════════════════════════
local _project_terminals = {}

local function get_terminal_key(dir)
  return project_root_or_cwd(dir or vim.fn.expand("%:p:h"))
end

local function get_project_terminal(dir)
  local key = get_terminal_key(dir)
  local term = _project_terminals[key]
  if term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
    return term, key
  end
  _project_terminals[key] = nil
  return nil, key
end

-- ═══════════════════════════════════════════════════════════════
-- TERMINAL EXECUTION
-- ═══════════════════════════════════════════════════════════════
local function term_exec(cmd, dir)
  if not cmd or cmd == "" then
    vim.notify("No command to execute", vim.log.levels.WARN)
    return
  end

  local term_dir = dir or get_terminal_key()
  local term_key = get_terminal_key(term_dir)
  local ok_tt, _ = pcall(require, "toggleterm")
  if not ok_tt then
    vim.cmd("botright split | lcd " .. vim.fn.fnameescape(term_dir) .. " | terminal " .. vim.fn.shellescape(cmd))
    vim.cmd("startinsert")
    return
  end

  local Terminal = require("toggleterm.terminal").Terminal
  local runner_term_instance = get_project_terminal(term_dir)

  local is_valid = runner_term_instance ~= nil
    and runner_term_instance.bufnr ~= nil
    and vim.api.nvim_buf_is_valid(runner_term_instance.bufnr)
    and runner_term_instance:is_open()

  if not is_valid then
    runner_term_instance = nil
    _project_terminals[term_key] = nil
  end

  local full_cmd = cmd
  if dir then
    full_cmd = "cd " .. vim.fn.shellescape(dir) .. " && " .. cmd
  end

  if not runner_term_instance then
    local pending_cmd = full_cmd
    local cmd_sent = false

    runner_term_instance = Terminal:new({
      direction = "horizontal",
      dir = term_dir,
      close_on_exit = false,
      on_create = function(term)
        if pending_cmd and not cmd_sent then
          vim.defer_fn(function()
            if not cmd_sent then
              term:send(pending_cmd, false)
              cmd_sent = true
              pending_cmd = nil
            end
          end, 50)
        end
      end,
      on_open = function(term)
        if pending_cmd and not cmd_sent then
          term:send(pending_cmd, false)
          cmd_sent = true
          pending_cmd = nil
        end
      end,
    })
    _project_terminals[term_key] = runner_term_instance
    runner_term_instance:open()
  else
    runner_term_instance:send(full_cmd, false)
  end
end

vim.keymap.set("n", "<leader>tt", function()
  local root = get_terminal_key()
  local term = get_project_terminal(root)
  if term and term:is_open() then
    term:close()
  else
    term_exec('echo "Project terminal (' .. root .. ')"', root)
  end
end, { silent = true, desc = "Toggle project terminal" })

local function exec_run_cmd(run_cmd, opts)
  if not run_cmd then
    return
  end
  if opts.input then
    run_cmd = append_input_redirect(run_cmd)
    if not run_cmd then
      return
    end
  end
  term_exec(run_cmd)
end

local function code_run(opts)
  opts = opts or {}
  local f = vim.fn.expand("%:p")
  local ft = vim.bo.filetype

  if f == "" or vim.bo.buftype ~= "" then
    vim.notify("Cannot run: no file associated with this buffer", vim.log.levels.WARN)
    return
  end

  if vim.bo.modified and vim.bo.modifiable then
    local ok_write, err = pcall(vim.cmd, "silent write")
    if not ok_write then
      vim.notify("Failed to save file before running: " .. tostring(err), vim.log.levels.WARN)
    end
  end

  local cfg = get_lang_cfg(ft)
  if not cfg then
    vim.notify("No runner configured for filetype: " .. ft, vim.log.levels.WARN)
    return
  end

  if cfg.deps and not check_deps(cfg.deps) then
    return
  end

  if not cfg.run and not cfg.compile and not cfg.project then
    vim.notify("No run command configured for: " .. ft, vim.log.levels.INFO)
    return
  end

  local root, proj = find_project(cfg)
  if proj then
    local action
    if opts.test and proj.test then
      action = resolve_action(proj.test)
    elseif opts.compile_only and proj.build then
      action = resolve_action(proj.build)
    elseif not opts.test and not opts.compile_only and proj.run then
      action = resolve_action(proj.run)
    end
    if action then
      if opts.compile_only then
        job_manager:compile(action, root, nil, 60000)
      else
        term_exec(action, root)
      end
      return
    end
  end

  if opts.test and not proj then
    vim.notify("No test configuration found for this project/file", vim.log.levels.WARN)
    return
  end

  if opts.force and not cfg.compile then
    vim.notify("No compile step — running normally", vim.log.levels.INFO)
  end

  if cfg.compile then
    local out = cfg.out and cfg.out(f) or nil
    local compile_cmd = cfg.compile(f, out)
    if not compile_cmd then
      vim.notify("Failed to generate compile command", vim.log.levels.ERROR)
      return
    end

    if opts.compile_only then
      job_manager:compile(compile_cmd, vim.fn.fnamemodify(f, ":h"), nil, 30000)
      return
    end

    local needs_compile = true
    if out and not opts.force then
      local out_time = vim.fn.getftime(out)
      local src_time = vim.fn.getftime(f)
      if out_time >= 0 and src_time >= 0 and out_time >= src_time then
        needs_compile = false
      end
    end

    if needs_compile then
      job_manager:compile(compile_cmd, vim.fn.fnamemodify(f, ":h"), function()
        exec_run_cmd(cfg.run(f, out), opts)
      end, 30000)
    else
      vim.notify("Up to date — skipping compilation", vim.log.levels.INFO)
      exec_run_cmd(cfg.run(f, out), opts)
    end
  else
    if not cfg.run then
      vim.notify("No run command configured for: " .. ft, vim.log.levels.INFO)
      return
    end
    exec_run_cmd(cfg.run(f), opts)
  end
end

vim.keymap.set("n", "<leader>cr", function()
  code_run()
end, { silent = true, desc = "Run" })

vim.keymap.set("n", "<leader>cI", function()
  code_run({ input = true })
end, { silent = true, desc = "Run (input.txt)" })

vim.keymap.set("n", "<leader>cB", function()
  code_run({ compile_only = true })
end, { silent = true, desc = "Build" })

vim.keymap.set("n", "<leader>cR", function()
  code_run({ force = true })
end, { silent = true, desc = "Rebuild + run" })

vim.keymap.set("n", "<leader>cX", function()
  job_manager:cancel()
end, { silent = true, desc = "Cancel job" })

vim.keymap.set("n", "<leader>ct", function()
  code_run({ test = true })
end, { silent = true, desc = "Test" })

M.job_manager = job_manager
M.get_project_terminal = get_project_terminal
M.term_exec = term_exec
M.exec_run_cmd = exec_run_cmd
M.code_run = code_run

return M
