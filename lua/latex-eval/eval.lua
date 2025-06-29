local M = {}

-- local function async_shell_command(cmd, callback)
--   -- Start the job without tmp file, just direct command
--   return vim.system(cmd, {}, function(obj)
--     callback(obj.code, obj.stdout, obj.stderr)
--   end)
-- end
local function async_shell_command(cmd, callback)
  vim.notify("Running command: " .. table.concat(cmd, " "), vim.log.levels.INFO)

  return vim.system(cmd, {}, vim.schedule_wrap(function(obj)
    vim.notify("Command completed with exit code: " .. tostring(obj.code), vim.log.levels.INFO)
    vim.notify("stdout: " .. tostring(obj.stdout), vim.log.levels.INFO)
    vim.notify("stderr: " .. tostring(obj.stderr), vim.log.levels.INFO)
    callback(obj.code, obj.stdout, obj.stderr)
  end))
end


M.evaluate_latex = function(latex_str)
  -- Call your evaluator script with latex_str as argument
  local command = { "python", "main.py", latex_str }

  vim.notify("one", vim.log.levels.INFO)

  async_shell_command(command, function(exit_code, stdout, stderr)
    if exit_code ~= 0 then
      print("Error while evaluating LaTeX:")
      print(stderr)
    else
      -- Copy result to clipboard
      vim.fn.setreg("+", stdout)
      print("Evaluated result copied to clipboard: " .. stdout)
    end
  end)
end

return M

