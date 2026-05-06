return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      
      harpoon:setup({
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
        },
      })

      local function get_current_file()
        local path = vim.fn.expand("%:.")
        if path == "" or path == "." then
          path = vim.fn.expand("%:p")
        end
        return path
      end

      local function is_in_harpoon(list, filepath)
        if not list.items or #list.items == 0 then
          return false, nil
        end
        for _, item in ipairs(list.items) do
          if item.value == filepath then
            return true, item
          end
        end
        return false, nil
      end

      local function get_harpoon_index(list, filepath)
        if not list.items then return nil end
        for i, item in ipairs(list.items) do
          if item.value == filepath then
            return i
          end
        end
        return nil
      end

      vim.keymap.set("n", "<leader>ha", function()
        local filepath = get_current_file()
        if filepath == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return
        end
        
        local list = harpoon:list()
        local exists, _ = is_in_harpoon(list, filepath)
        
        if exists then
          vim.notify("Already in harpoon", vim.log.levels.INFO)
        else
          list:add()
          vim.notify("Added to harpoon", vim.log.levels.INFO)
        end
      end, { silent = true, desc = "Harpoon add" })

      vim.keymap.set("n", "<leader>hh", function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { silent = true, desc = "Harpoon menu" })

      vim.keymap.set("n", "<leader>hd", function()
        local list = harpoon:list()
        local filepath = get_current_file()
        
        if filepath == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return
        end
        
        if not list.items or #list.items == 0 then
          vim.notify("Harpoon list is empty", vim.log.levels.WARN)
          return
        end
        
        local exists, item = is_in_harpoon(list, filepath)
        
        if exists then
          list:remove(item)
          vim.notify("Removed from harpoon", vim.log.levels.INFO)
        else
          vim.notify("File not in harpoon list", vim.log.levels.WARN)
        end
      end, { silent = true, desc = "Harpoon delete current" })

      vim.keymap.set("n", "<leader>hC", function()
        local list = harpoon:list()
        if not list.items or #list.items == 0 then
          vim.notify("Harpoon list is already empty", vim.log.levels.INFO)
          return
        end
        
        local count = #list.items
        for i = count, 1, -1 do
          list:remove(list.items[i])
        end
        
        vim.notify("Cleared " .. count .. " items from harpoon", vim.log.levels.INFO)
      end, { silent = true, desc = "Harpoon clear all" })

      vim.keymap.set("n", "<leader>hs", function()
        local list = harpoon:list()
        local filepath = get_current_file()
        
        if filepath == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return
        end
        
        if not list.items or #list.items == 0 then
          vim.notify("Harpoon list is empty", vim.log.levels.INFO)
          return
        end
        
        local index = get_harpoon_index(list, filepath)
        
        if index then
          vim.notify("Current file is harpoon #" .. index .. " of " .. #list.items, vim.log.levels.INFO)
        else
          vim.notify("Current file is not in harpoon (" .. #list.items .. " items total)", vim.log.levels.INFO)
        end
      end, { silent = true, desc = "Harpoon status" })

      for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, function()
          harpoon:list():select(i)
        end, { silent = true, desc = "Harpoon " .. i })
      end
    end,
  },
}
