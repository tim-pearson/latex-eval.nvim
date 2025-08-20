local M = {}
local function async_shell_command(cmd, callback)
  return vim.system(cmd, {}, vim.schedule_wrap(function(obj)
    callback(obj.code, obj.stdout, obj.stderr)
  end))
end


M.evaluate_latex = function(latex_str, symbolic)
  local plugin_path = debug.getinfo(1, 'S').source:sub(2):match("(.*/)")
  local mode = symbolic and "symbolic" or ""
  local command = symbolic
      and { "python", plugin_path .. "../../main.py", "symbolic", latex_str }
      or { "python", plugin_path .. "../../main.py", latex_str }

  -- async_shell_command(command, function(exit_code, stdout, stderr)
  --   if exit_code ~= 0 then
  --     vim.notify("Error while evaluating LaTeX:\n" .. stderr, vim.log.levels.ERROR)
  --   else
  --     local result = stdout:gsub("%s+$", "")

  --     local line = vim.api.nvim_get_current_line()
  --     vim.api.nvim_set_current_line(line .. " " .. result)

  --     vim.fn.setreg("+", result)

  --     local mode_label = symbolic and "[Symbolic]" or "[Numeric]"
  --     -- vim.notify("✔ " .. mode_label .. " Result: " .. result .. " (copied and inserted)", vim.log.levels.INFO)
  --   end
  -- end)
  --
  async_shell_command(command, function(exit_code, stdout, stderr)
    if exit_code ~= 0 then
      vim.notify("Error while evaluating LaTeX:\n" .. stderr, vim.log.levels.ERROR)
    else
      local result = stdout:gsub("%s+$", "")
      local current_line = vim.api.nvim_get_current_line()

      -- Split output (current line + result) by newlines
      local lines = {}
      for l in (current_line .. " " .. result):gmatch("[^\r\n]+") do
        table.insert(lines, l)
      end

      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      vim.api.nvim_buf_set_lines(0, row, row + 1, false, lines)

      vim.fn.setreg("+", result)

      local mode_label = symbolic and "[Symbolic]" or "[Numeric]"
      -- vim.notify("✔ " .. mode_label .. " Result: " .. result .. " (copied and inserted)", vim.log.levels.INFO)
    end
  end)
end


M.solve_latex = function(latex_str, var)
  local plugin_path = debug.getinfo(1, 'S').source:sub(2):match("(.*/)")
  local command = { "python", plugin_path .. "../../main.py", "solve", latex_str, var }


  async_shell_command(command, function(exit_code, stdout, stderr)
    if exit_code ~= 0 then
      vim.notify("Error while evaluating LaTeX:\n" .. stderr, vim.log.levels.ERROR)
    else
      local result = stdout:gsub("%s+$", "")

      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_set_lines(0, row, row, false, { result })

      vim.fn.setreg("+", result)

      local mode_label = "[Solve]"
      vim.notify("✔ " .. mode_label .. " Result: " .. result .. " (copied and inserted)", vim.log.levels.INFO)
    end
  end)
end

M.diff_latex = function(latex_str, symbols, var)
  local plugin_path = debug.getinfo(1, 'S').source:sub(2):match("(.*/)")
  local command = { "python", plugin_path .. "../../main.py", "diff", latex_str, symbols, var }

  async_shell_command(command, function(exit_code, stdout, stderr)
    if exit_code ~= 0 then
      vim.notify("Error while differentiating LaTeX:\n" .. stderr, vim.log.levels.ERROR)
    else
      local result = stdout:gsub("%s+$", "")

      -- copy to clipboard only
      vim.fn.setreg("+", result)

      local mode_label = "[Differentiate]"
      vim.notify("✔ " .. mode_label .. " Result copied to clipboard: " .. result, vim.log.levels.INFO)
    end
  end)
end

return M
