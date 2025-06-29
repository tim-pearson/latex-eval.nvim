local M = {}

local eval = require("latex-eval.eval") -- renamed share.lua to eval.lua

local function get_visual_selection()
  vim.notify("Entering get_visual_selection", vim.log.levels.DEBUG)
  local mode = vim.fn.mode()
  if not (mode == "v" or mode == "V" or mode == "␖") then
    vim.notify("Not in visual mode", vim.log.levels.WARN)

    return nil
  end

  local original_clip = vim.fn.getreg('"')
  local original_clip_type = vim.fn.getregtype('"')

  vim.cmd("silent normal! y")
  local selection = vim.fn.getreg('"')
  vim.fn.setreg('"', original_clip, original_clip_type)
  vim.notify("Visual selection captured: " .. selection, vim.log.levels.DEBUG)

  return selection
end

function M.evaluate_visual()
  vim.notify("Calling evaluate_visual", vim.log.levels.INFO)

  local selection = get_visual_selection()
  if selection then
    vim.notify("Sending selection to evaluator: " .. selection, vim.log.levels.INFO)


    eval.evaluate_latex(selection)
  else
    vim.notify("No visual selection found to evaluate", vim.log.levels.ERROR)

    print("No visual selection found.")
  end
end

return M

