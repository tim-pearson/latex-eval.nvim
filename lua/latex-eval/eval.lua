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
      or  { "python", plugin_path .. "../../main.py", latex_str }

  async_shell_command(command, function(exit_code, stdout, stderr)
    if exit_code ~= 0 then
      vim.notify("Error while evaluating LaTeX:\n" .. stderr, vim.log.levels.ERROR)
    else
      local result = stdout:gsub("%s+$", "")

      local line = vim.api.nvim_get_current_line()
      vim.api.nvim_set_current_line(line .. " " .. result)

      vim.fn.setreg("+", result)

      local mode_label = symbolic and "[Symbolic]" or "[Numeric]"
      vim.notify("✔ " .. mode_label .. " Result: " .. result .. " (copied and inserted)", vim.log.levels.INFO)
    end
  end)
end

return M

