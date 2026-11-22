local common = require("latex-eval.features.common")

local M = {}

local function attempt(selection, options)
  local run_options = vim.deepcopy(options)
  run_options.on_error = function(error)
    local ui = require("latex-eval.ui")
    if error.code == "AMBIGUOUS_VARIABLE" then
      local candidates = error.details and error.details.candidates or {}
      ui.prompt_variable(candidates, function(variable)
        if variable and variable ~= "" then
          run_options.variable = variable
          attempt(selection, run_options)
        end
      end)
      return true
    end
    if error.code == "MISSING_VARIABLE" then
      ui.prompt_variable(nil, function(variable)
        if variable and variable ~= "" then
          run_options.variable = variable
          attempt(selection, run_options)
        end
      end)
      return true
    end
    return false
  end

  common.run("differentiate", selection, run_options, function(response, resolved)
    common.show(response, resolved, { title = "Differentiate" })
  end)
end

function M.run(selection, options)
  options = options or {}
  local resolved = common.resolve_selection(selection, options)
  if not resolved then
    return
  end
  attempt(resolved, options)
end

return M