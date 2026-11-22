local M = {}

local created = {}

local function config()
  return require("latex-eval.config").get()
end

local function clear()
  for _, entry in ipairs(created) do
    pcall(vim.keymap.del, entry.mode, entry.lhs)
  end
  created = {}
end

local function action_specs()
  return {
    {
      name = "menu",
      modes = { "n" },
      description = "Open latex-eval menu",
      run = function()
        require("latex-eval").menu()
      end,
    },
    {
      name = "evaluate",
      modes = { "n", "x" },
      description = "Evaluate LaTeX math",
      run = function()
        require("latex-eval").evaluate()
      end,
    },
    {
      name = "simplify",
      modes = { "n", "x" },
      description = "Simplify LaTeX math",
      run = function()
        require("latex-eval").simplify()
      end,
    },
    {
      name = "solve",
      modes = { "n", "x" },
      description = "Solve LaTeX equation",
      run = function()
        require("latex-eval").solve()
      end,
    },
    {
      name = "define",
      modes = { "n", "x" },
      description = "Store LaTeX definition",
      run = function()
        require("latex-eval").define()
      end,
    },
    {
      name = "differentiate",
      modes = { "n", "x" },
      description = "Differentiate LaTeX math",
      run = function()
        require("latex-eval").differentiate()
      end,
    },
    {
      name = "align",
      modes = { "n", "x" },
      description = "Join or split aligned math",
      run = function()
        require("latex-eval").toggle_align()
      end,
    },
    {
      name = "definitions",
      modes = { "n" },
      description = "Manage latex-eval definitions",
      run = function()
        require("latex-eval").definitions()
      end,
    },
    {
      name = "health",
      modes = { "n" },
      description = "latex-eval health check",
      run = function()
        require("latex-eval").health()
      end,
    },
  }
end

local function key_for(name, settings)
  local override = settings.overrides and settings.overrides[name]
  if override == false then
    return nil
  end
  if type(override) == "string" and override ~= "" then
    return override
  end

  local suffix = settings.mappings and settings.mappings[name]
  if suffix == false or suffix == nil or suffix == "" then
    return nil
  end
  return (settings.prefix or "<leader>b") .. suffix
end

function M.setup()
  clear()
  local settings = config().keymaps
  if settings.enabled == false then
    return
  end

  for _, spec in ipairs(action_specs()) do
    local lhs = key_for(spec.name, settings)
    if lhs then
      for _, mode in ipairs(spec.modes) do
        local existing = vim.fn.maparg(lhs, mode)
        if existing ~= "" then
          require("latex-eval.ui").warn(
            "Not overriding existing mapping " .. lhs .. " (" .. mode .. ")"
          )
        else
          vim.keymap.set(mode, lhs, spec.run, {
            silent = settings.silent ~= false,
            nowait = true,
            desc = spec.description,
          })
          created[#created + 1] = { mode = mode, lhs = lhs }
        end
      end
    end
  end
end

function M.clear()
  clear()
end

return M