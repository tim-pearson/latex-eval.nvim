local M = {}

local PRESETS = {
  { name = "boxed", label = "\\boxed{...}" },
  { name = "underbrace", label = "\\underbrace{...}" },
  { name = "overbrace", label = "\\overbrace{...}" },
  { name = "cancel", label = "\\cancel{...}" },
  { name = "sqrt", label = "\\sqrt{...}" },
  { name = "text", label = "\\text{...}" },
  { name = "overline", label = "\\overline{...}" },
  { name = "underline", label = "\\underline{...}" },
  { name = "hat", label = "\\hat{...}" },
  { name = "bar", label = "\\bar{...}" },
  { name = "vec", label = "\\vec{...}" },
  { name = "tilde", label = "\\tilde{...}" },
  { name = "dot", label = "\\dot{...}" },
  { name = "ddot", label = "\\ddot{...}" },
  { name = "mathbf", label = "\\mathbf{...}" },
  { name = "mathrm", label = "\\mathrm{...}" },
  { name = "operatorname", label = "\\operatorname{...}" },
}

local BY_NAME = {}
for _, preset in ipairs(PRESETS) do
  BY_NAME[preset.name] = preset
end

local function ui()
  return require("latex-eval.ui")
end

function M.names()
  local names = {}
  for _, preset in ipairs(PRESETS) do
    names[#names + 1] = preset.name
  end
  return names
end

function M.wrap(name, options)
  options = options or {}
  local preset = BY_NAME[name]
  if not preset then
    ui().warn(
      "Unknown math wrapper '"
        .. tostring(name)
        .. "'. Try: "
        .. table.concat(M.names(), ", ")
    )
    return
  end

  local selection = options.selection
  if not selection then
    selection = require("latex-eval.selection").get()
  end
  if not selection then
    return
  end
  if vim.trim(selection.text or "") == "" then
    ui().warn("Nothing to wrap")
    return
  end

  local wrapped = "\\" .. name .. "{" .. selection.text .. "}"
  local ok, error_message = pcall(
    require("latex-eval.ui").apply_inline,
    wrapped,
    {
      selection = selection,
      inline_mode = "replace",
      bufnr = options.bufnr,
      win = options.win,
    }
  )
  if not ok then
    ui().error("Could not wrap expression: " .. tostring(error_message))
    return
  end
  ui().info("Wrapped in " .. preset.label)
end

function M.menu(options)
  vim.ui.select(PRESETS, {
    prompt = "Wrap math in:",
    format_item = function(preset)
      return preset.label
    end,
  }, function(choice)
    if choice then
      M.wrap(choice.name, options)
    end
  end)
end

return M