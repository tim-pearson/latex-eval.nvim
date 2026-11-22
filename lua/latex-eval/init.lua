local M = {}

local initialized = false

local function config()
  return require("latex-eval.config")
end

local function selection_module()
  return require("latex-eval.selection")
end

local function features()
  return require("latex-eval.features")
end

local function ui()
  return require("latex-eval.ui")
end

function M.setup(options)
  config().setup(options)
  require("latex-eval.commands").setup()
  require("latex-eval.keymaps").setup()
  initialized = true
  vim.g.latex_eval_configured = 1
  return M
end

local function ensure()
  if not initialized then
    M.setup(nil)
  end
end

local function run_feature(name, options)
  ensure()
  options = options or {}
  local feature = features().get(name)
  if not feature then
    ui().error("Unknown latex-eval feature: " .. name)
    return
  end
  feature.run(options.selection, options)
end

function M.evaluate(options)
  run_feature("evaluate", options)
end

function M.simplify(options)
  run_feature("simplify", options)
end

function M.solve(options)
  run_feature("solve", options)
end

function M.differentiate(options)
  run_feature("differentiate", options)
end

function M.define(options)
  run_feature("define", options)
end

function M.preview()
  ensure()
  ui().warn(
    "Preview was removed because mdmath.nvim does not render floating windows"
  )
end

function M.wrap(name, options)
  ensure()
  require("latex-eval.wrap").wrap(name, options)
end

function M.wrap_menu(options)
  ensure()
  require("latex-eval.wrap").menu(options)
end

function M.toggle_align()
  ensure()
  require("latex-eval.transform").toggle()
end

function M.join_math()
  ensure()
  require("latex-eval.transform").join()
end

function M.split_math()
  ensure()
  require("latex-eval.transform").split()
end

function M.menu()
  ensure()
  require("latex-eval.menu").open()
end

function M.definitions()
  ensure()
  require("latex-eval.features.define").manage()
end

function M.health(callback)
  ensure()
  local python = require("latex-eval.python")
  if callback then
    python.health(callback)
    return
  end
  python.health(function(report, ok)
    ui().open_float(report, {
      title = ok and "latex-eval health" or "latex-eval health (issues)",
      max_width = 100,
    })
  end)
end

function M.install(callback)
  ensure()
  require("latex-eval.python").install(callback)
end

function M.run(name, selection, options)
  ensure()
  options = options or {}
  options.selection = selection or options.selection
  run_feature(name, options)
end

function M.evaluate_visual(symbolic)
  ensure()
  local selection = selection_module().get()
  if not selection then
    return
  end
  features()
    .get(symbolic and "simplify" or "evaluate")
    .run(selection, {})
end

function M.solve_visual()
  ensure()
  local selection = selection_module().get()
  if not selection then
    return
  end
  features().get("solve").run(selection, {})
end

function M.diff_visual()
  ensure()
  local selection = selection_module().get()
  if not selection then
    return
  end
  features().get("differentiate").run(selection, {})
end

return M