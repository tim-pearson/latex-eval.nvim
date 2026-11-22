local M = {}

local registry = {}

function M.register(name, module)
  registry[name] = module
end

function M.get(name)
  return registry[name]
end

function M.run(name, selection, options)
  local feature = registry[name]
  if not feature then
    require("latex-eval.ui").error("Unknown latex-eval feature: " .. name)
    return
  end
  feature.run(selection, options or {})
end

function M.names()
  local names = {}
  for name in pairs(registry) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

M.register("evaluate", require("latex-eval.features.evaluate"))
M.register("simplify", require("latex-eval.features.simplify"))
M.register("solve", require("latex-eval.features.solve"))
M.register("differentiate", require("latex-eval.features.differentiate"))
M.register("define", require("latex-eval.features.define"))

return M