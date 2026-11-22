local common = require("latex-eval.features.common")

local M = {}

function M.run(selection, options)
  options = options or {}
  common.run("evaluate", selection, options, function(response, resolved)
    common.show(response, resolved, { title = "Evaluate" })
  end)
end

return M