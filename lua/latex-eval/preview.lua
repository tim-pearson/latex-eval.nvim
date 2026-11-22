local M = {}

local GREEK = {
  { "\\alpha", "α" },
  { "\\beta", "β" },
  { "\\gamma", "γ" },
  { "\\delta", "δ" },
  { "\\epsilon", "ε" },
  { "\\varepsilon", "ε" },
  { "\\zeta", "ζ" },
  { "\\eta", "η" },
  { "\\theta", "θ" },
  { "\\vartheta", "ϑ" },
  { "\\iota", "ι" },
  { "\\kappa", "κ" },
  { "\\lambda", "λ" },
  { "\\mu", "μ" },
  { "\\nu", "ν" },
  { "\\xi", "ξ" },
  { "\\pi", "π" },
  { "\\rho", "ρ" },
  { "\\sigma", "σ" },
  { "\\tau", "τ" },
  { "\\upsilon", "υ" },
  { "\\phi", "φ" },
  { "\\varphi", "ϕ" },
  { "\\chi", "χ" },
  { "\\psi", "ψ" },
  { "\\omega", "ω" },
  { "\\Gamma", "Γ" },
  { "\\Delta", "Δ" },
  { "\\Theta", "Θ" },
  { "\\Lambda", "Λ" },
  { "\\Xi", "Ξ" },
  { "\\Pi", "Π" },
  { "\\Sigma", "Σ" },
  { "\\Phi", "Φ" },
  { "\\Psi", "Ψ" },
  { "\\Omega", "Ω" },
}

local SYMBOLS = {
  { "\\cdot", "·" },
  { "\\times", "×" },
  { "\\div", "÷" },
  { "\\pm", "±" },
  { "\\mp", "∓" },
  { "\\infty", "∞" },
  { "\\leq", "≤" },
  { "\\le", "≤" },
  { "\\geq", "≥" },
  { "\\ge", "≥" },
  { "\\neq", "≠" },
  { "\\ne", "≠" },
  { "\\approx", "≈" },
  { "\\equiv", "≡" },
  { "\\rightarrow", "→" },
  { "\\to", "→" },
  { "\\leftarrow", "←" },
  { "\\sum", "∑" },
  { "\\prod", "∏" },
  { "\\int", "∫" },
  { "\\partial", "∂" },
  { "\\nabla", "∇" },
  { "\\in", "∈" },
  { "\\notin", "∉" },
  { "\\subset", "⊂" },
  { "\\cup", "∪" },
  { "\\cap", "∩" },
  { "\\forall", "∀" },
  { "\\exists", "∃" },
  { "\\emptyset", "∅" },
  { "\\angle", "∠" },
  { "\\circ", "°" },
  { "\\hbar", "ℏ" },
}

local SUPERSCRIPTS = {
  ["0"] = "⁰",
  ["1"] = "¹",
  ["2"] = "²",
  ["3"] = "³",
  ["4"] = "⁴",
  ["5"] = "⁵",
  ["6"] = "⁶",
  ["7"] = "⁷",
  ["8"] = "⁸",
  ["9"] = "⁹",
  ["+"] = "⁺",
  ["-"] = "⁻",
  ["="] = "⁼",
  ["("] = "⁽",
  [")"] = "⁾",
  ["n"] = "ⁿ",
  ["i"] = "ⁱ",
}

local SUBSCRIPTS = {
  ["0"] = "₀",
  ["1"] = "₁",
  ["2"] = "₂",
  ["3"] = "₃",
  ["4"] = "₄",
  ["5"] = "₅",
  ["6"] = "₆",
  ["7"] = "₇",
  ["8"] = "₈",
  ["9"] = "₉",
  ["+"] = "₊",
  ["-"] = "₋",
  ["="] = "₌",
  ["("] = "₍",
  [")"] = "₎",
  ["a"] = "ₐ",
  ["e"] = "ₑ",
  ["i"] = "ᵢ",
  ["o"] = "ₒ",
  ["u"] = "ᵤ",
  ["x"] = "ₓ",
}

local function replace_script(value, pattern, mapping)
  return (value:gsub(pattern, function(content)
    local converted = {}
    for index = 1, #content do
      local character = content:sub(index, index)
      local replacement = mapping[character]
      if not replacement then
        return nil
      end
      converted[#converted + 1] = replacement
    end
    return table.concat(converted)
  end))
end

function M.prettify(value)
  local result = value
  for _, pair in ipairs(GREEK) do
    result = result:gsub(pair[1], pair[2])
  end
  for _, pair in ipairs(SYMBOLS) do
    result = result:gsub(pair[1], pair[2])
  end
  result = result:gsub("\\frac{([^{}]+)}{([^{}]+)}", "(%1)/(%2)")
  result = result:gsub("\\sqrt{([^{}]+)}", "√(%1)")
  result = result:gsub("\\left", "")
  result = result:gsub("\\right", "")
  result = result:gsub("\\,", " ")
  result = result:gsub("\\;", " ")
  result = result:gsub("\\!", "")
  result = result:gsub("\\quad", "  ")
  result = result:gsub("\\qquad", "    ")
  result = replace_script(result, "%^{([^}]+)}", SUPERSCRIPTS)
  result = replace_script(result, "_{([^}]+)}", SUBSCRIPTS)
  return result
end

function M.open(selection)
  if not selection then
    return
  end

  local config = require("latex-eval.config").get()
  local selection_module = require("latex-eval.selection")
  local source = selection_module.strip_math_delimiters(selection.text)
  if source == "" then
    require("latex-eval.ui").warn("Nothing to preview")
    return
  end

  local display = config.preview.unicode and M.prettify(source) or source
  local lines = vim.split(display, "\n", { plain = true })
  if config.preview.show_source and display ~= source then
    lines[#lines + 1] = ""
    lines[#lines + 1] = source
  end

  local title = config.preview.title
  if selection.environment then
    title = title .. " [" .. selection.environment .. "]"
  end

  require("latex-eval.ui").open_float(lines, {
    title = title,
    border = config.preview.border,
    max_width = config.preview.max_width,
    max_height = config.preview.max_height,
    filetype = config.preview.filetype,
    close_key = config.preview.close_key,
  })
end

return M