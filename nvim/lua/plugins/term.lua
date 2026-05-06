
local helpers = require("utils.helpers")
local CURRENT_OS = helpers.CURRENT_OS
local is_dir = helpers.is_dir
local has_cmd = helpers.has_cmd
local has_file = helpers.has_file

return {
  {
    "akinsho/toggleterm.nvim",
    config = function()
      require("toggleterm").setup({
        size = 15,
        open_mapping = [[<C-t>]],
        direction = "horizontal",
        shade_terminals = true,
        on_open = function(_)
          vim.cmd("startinsert")
        end,
      })
    end,
  },

  {
    "barrettruth/live-server.nvim",
    ft = { "html", "css", "javascript", "javascriptreact", "typescript", "typescriptreact", "ejs" },
    cmd = { "LiveServerStart", "LiveServerStop" },
    init = function()
      -- ══════════════════════════════════════════════════════════════
      -- WSL BROWSER
      -- ══════════════════════════════════════════════════════════════
      if CURRENT_OS == "linux" and is_dir("/mnt/c") then
        local open_cmd
        if has_cmd("wslview") then
          open_cmd = "wslview"
        elseif has_file("/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe") then
          open_cmd = "/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe"
        end
        if open_cmd then
          local orig_open = vim.ui.open
          vim.ui.open = function(target, opts)
            if target and target:match("^https?://") then
              vim.system({ open_cmd, target }, opts or {})
            elseif orig_open then
              orig_open(target, opts)
            end
          end
        end
      end

      -- ══════════════════════════════════════════════════════════════
      -- LIVE SERVER
      -- ══════════════════════════════════════════════════════════════
      
      local alt_server = {
        port = nil,
        job = nil,
        pid = nil,
      }
      
      local function run_system(cmd)
        local ok, result = pcall(function()
          return vim.system(cmd, { text = true }):wait()
        end)
        if not ok or not result then
          return { code = 1, stdout = "", stderr = "" }
        end
        return result
      end

      local function lsof_pids(port)
        if not has_cmd("lsof") then
          return {}
        end
        local result = run_system({ "lsof", "-ti:" .. tostring(port) })
        if result.code ~= 0 then
          return {}
        end
        local pids, seen = {}, {}
        for pid in (result.stdout or ""):gmatch("%d+") do
          if not seen[pid] then
            seen[pid] = true
            pids[#pids + 1] = pid
          end
        end
        return pids
      end

      local function is_port_in_use(port)
        if not port then return false end
        if CURRENT_OS == "mac" then
          return #lsof_pids(port) > 0
        end
        if CURRENT_OS == "linux" then
          if has_cmd("fuser") then
            return run_system({ "fuser", ("%d/tcp"):format(port) }).code == 0
          end
          return #lsof_pids(port) > 0
        end
        return false
      end

      local function kill_port(port)
        if not port then return end
        if CURRENT_OS == "linux" and has_cmd("fuser") then
          vim.system({ "fuser", "-k", ("%d/tcp"):format(port) }, { stdout = false, stderr = false })
          return
        end
        for _, pid in ipairs(lsof_pids(port)) do
          vim.system({ "kill", tostring(pid) }, { stdout = false, stderr = false })
        end
      end

      local function kill_alt_server()
        if alt_server.port and is_port_in_use(alt_server.port) then
          kill_port(alt_server.port)
        end
        
        if alt_server.job then
          pcall(vim.fn.jobstop, alt_server.job)
          alt_server.job = nil
        end
        
        alt_server.port = nil
        alt_server.pid = nil
      end

      local function open_when_ready(host, port, max_wait_ms, on_ready)
        local elapsed = 0
        local step = 100
        local timer = vim.uv.new_timer()
        if not timer then return end
        timer:start(step, step, vim.schedule_wrap(function()
          elapsed = elapsed + step
          if elapsed > max_wait_ms then
            timer:stop()
            timer:close()
            vim.notify(
              ("live-server on port %d didn't respond after %.1fs"):format(port, max_wait_ms / 1000),
              vim.log.levels.WARN
            )
            return
          end
          local sock = vim.uv.new_tcp()
          if not sock then return end
          sock:connect(host, port, function(err)
            sock:close()
            if not err then
              timer:stop()
              timer:close()
              vim.ui.open(("http://%s:%d/"):format(host, port))
              if on_ready then on_ready() end
            end
          end)
        end))
      end

      local function start_alt_server(port)
        if is_port_in_use(port) then
          vim.notify(string.format("Port %d already in use, opening browser", port), vim.log.levels.INFO)
          vim.ui.open(string.format("http://127.0.0.1:%d/", port))
          return
        end
        
        kill_alt_server()
        pcall(function() require("live-server").stop() end)
        kill_port(port)

        local dir = vim.fn.expand("%:p:h")
        
        local job_id = vim.fn.jobstart({
          "live-server",
          "--port=" .. port,
          "--no-browser",
          "--quiet",
          dir,
        }, { 
          detach = true,
          on_exit = function()
            alt_server.port = nil
            alt_server.job = nil
            alt_server.pid = nil
          end
        })
        
        if job_id <= 0 then
          vim.notify("live-server: failed to start — is it installed? (npm i -g live-server)", vim.log.levels.ERROR)
          return
        end
        
        pcall(function()
          alt_server.pid = vim.fn.jobpid(job_id)
        end)
        alt_server.job = job_id
        alt_server.port = port
        
        open_when_ready("127.0.0.1", port, 5000)
      end

      local function stop_all_servers()
        pcall(function() require("live-server").stop() end)
        
        kill_alt_server()
        
        vim.notify("All live servers stopped", vim.log.levels.INFO)
      end

      vim.api.nvim_create_user_command("LiveServerStop", stop_all_servers, {})

      vim.keymap.set("n", "<leader>vs", function()
        if is_port_in_use(8080) then
          vim.notify("Port 8080 already in use, opening browser", vim.log.levels.INFO)
          vim.ui.open("http://127.0.0.1:8080/")
          return
        end
        kill_alt_server()
        require("live-server").start()
        vim.notify("live-server started (port 8080)", vim.log.levels.INFO)
      end, { desc = "Live server start (port 8080)" })

      vim.keymap.set("n", "<leader>vS", function()
        start_alt_server(3000)
      end, { desc = "Live server start (port 3000)" })

      vim.keymap.set("n", "<leader>vx", function()
        stop_all_servers()
      end, { desc = "Live server stop" })

      vim.api.nvim_create_autocmd("VimLeavePre", {
        once = true,
        callback = kill_alt_server,
      })

      vim.g.live_server = {
        port = 8080,
        browser = true,
        css_inject = true,
      }
    end,
  },
}