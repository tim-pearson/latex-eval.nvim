# latex-eval.nvim

latex-eval.nvim is a Neovim plugin that lets you evaluate,
simplify, or solve LaTeX math expressions directly inside your editor.
It parses and processes highlighted LaTeX math expressions using 
Python’s sympy and latex2sympy2 libraries and pastes the result at the
end of the current line.

---

## Features

This plugin supports three core operations on LaTeX math expressions:

1. Evaluate
```lua
require("latex-eval").evaluate_visual()
```
Numerically evaluates the highlighted LaTeX expression. Supports constants like the speed of light `c`.

Example:  
Select: `\frac{1}{2} \cdot 9.11 \times 10^{-31} \cdot c^2`  
Output: `\approx 4.10 \times 10^{-14}`

2. Simplify
```lua
require("latex-eval").evaluate_visual(true)
```
Symbolically simplifies the selected expression using SymPy's simplifier.

Example:  
Select: `\frac{e^{\ln(c^2)}}{c}`  
Output: `c`

3. Solve (`<leader>bz`)  
```lua
require("latex-eval").solve_visual(true)
```
Solves a LaTeX-formatted equation (like `E = mc^2`) for a given variable.  
You must format the expression as an equation (`=`) and include only one variable to solve for.

Example:  
Select: `E = mc^2`, then run the solve command  
Output: `m = \frac{E}{c^2}`

---

## Usage Instructions

1. Visually select a LaTeX expression or equation in visual mode.  
2. Press the relevant keybinding.  
3. The plugin parses the highlighted text and prints the result inline or in a message.

---

## Installation

### 1. Install Python Dependencies

```bash
pip install latex2sympy2
pip install sympy
```

## Example lua config

```lua
return {
  "tim-pearson/latex-eval.nvim",
  config = function()
    require("which-key").add({
      mode = "v",
      { "<Leader>b", group = "LatexEval" },
      {
        "<leader>bx",
        function()
          require("latex-eval").evaluate_visual()
        end,
        desc = "evaluate latex visual selection",
      },
      {
        "<leader>bs",
        function()
          require("latex-eval").evaluate_visual(true)
        end,
        desc = "simplify latex visual selection",
      },
      {
        "<leader>bz",
        function()
          require("latex-eval").solve_visual(true)
        end,
        desc = "solve latex visual selection",
      },
    })
  end,
  dependencies = {},
}

