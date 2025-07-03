local M = {}

local eval = require("latex-eval.eval") -- renamed share.lua to eval.lua

local function get_visual_selection()
  local mode = vim.fn.mode()
  if not (mode == "v" or mode == "V" or mode == "␖") then
    return nil
  end

  local original_clip = vim.fn.getreg('"')
  local original_clip_type = vim.fn.getregtype('"')

  vim.cmd("silent normal! y")
  local selection = vim.fn.getreg('"')
  vim.fn.setreg('"', original_clip, original_clip_type)

  return selection
end

function M.evaluate_visual(symbolic)
  local selection = get_visual_selection()
  if selection then
    eval.evaluate_latex(selection, symbolic)
  else
    vim.notify("No visual selection found to evaluate", vim.log.levels.ERROR)

    print("No visual selection found.")
  end
end

function M.solve_visual()
  local selection = get_visual_selection()
  if not selection then
    vim.notify("No visual selection found to evaluate", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({ prompt = "Solve for variable: " }, function(var)
    if var and var ~= "" then
      eval.solve_latex(selection, var)
    else
      vim.notify("No variable provided", vim.log.levels.WARN)
    end
  end)
end

