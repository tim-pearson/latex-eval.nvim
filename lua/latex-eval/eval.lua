local M = {}

local function async_shell_command(cmd, callback)
  -- Start the job without tmp file, just direct command
  return vim.system(cmd, {}, function(obj)
    callback(obj.code, obj.stdout, obj.stderr)
  end)
end

M.evaluate_latex = function(latex_str)
  -- Call your evaluator script with latex_str as argument
  local command = { "python", "main.py", latex_str }

  vim.notify("one", vim.log.levels.INFO)

  async_shell_command(command, function(exit_code, stdout, stderr)
    if exit_code ~= 0 then
  vim.notify("err1", vim.log.levels.INFO)
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

