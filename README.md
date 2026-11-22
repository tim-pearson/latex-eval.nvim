# latex-eval.nvim

`latex-eval.nvim` evaluates, simplifies, solves, differentiates, previews, and
stores LaTeX math while editing Markdown and LaTeX source.

It is designed to work alongside your existing Markdown rendering setup. It does
not render math and it does not replace `mdmath.nvim` or Kitty. `mdmath.nvim`
remains responsible for rendering; `latex-eval.nvim` only reads and modifies the
underlying Markdown source. When the plugin changes the buffer, an existing
Markdown renderer can update normally.

Requires Neovim 0.10 or newer.

---

## Features

- Evaluate expressions numerically or symbolically.
- Simplify expressions with SymPy.
- Solve equations, inferring the variable when unambiguous.
- Differentiate expressions or equation forms.
- Detect math under the cursor or use a visual selection.
- Work in normal mode or visual mode.
- Show results in a floating window and copy them to the clipboard.
- Replace only the mathematical source, preserving Markdown delimiters and the
  surrounding document.
- Store persistent values and user-defined functions.
- Isolated Python environment with pinned dependencies.
- Configurable commands, keymaps, result behavior, and definition paths.
- Optional Treesitter-assisted math detection.
- Optional Unicode text prettification for previews (no image rendering).

---

## Installation

### lazy.nvim

```lua
return {
  "tim-pearson/latex-eval.nvim",
  config = function()
    require("latex-eval").setup()
  end,
}
```

The plugin also creates its commands and default keymaps automatically if you do
not call `setup()`. Calling `setup()` lets you override configuration.

### Python dependencies

Do not install packages into system Python or a Conda environment. On first use,
`latex-eval.nvim` creates an isolated environment at:

```text
stdpath("data")/latex-eval/venv
```

It prompts before installing. Installation prefers `uv` when available and falls
back to `python3 -m venv` plus pip.

Manual environment commands:

```vim
:LatexEvalInstall
:LatexEvalHealth
```

`latex-eval.nvim` never installs into the host Python environment or the plugin
repository.

If `python3 -m venv` is unavailable on your system, install the OS package for
`venv` (for example `python3-venv` on Debian/Ubuntu) or install `uv`.

---

## Operations

| Operation | Description |
| --- | --- |
| Evaluate | Numerically evaluates an expression when possible; returns symbolic output otherwise. |
| Simplify | Symbolically simplifies with SymPy. |
| Solve | Solves an equation. The target variable is inferred when there is exactly one unknown; otherwise you are prompted. |
| Differentiate | Differentiates with respect to an inferred variable, or an explicitly supplied variable. For equation input, the left-hand side is preserved and the right-hand side is differentiated. |
| Preview | Shows the detected math source in a floating window. |
| Define | Stores a value such as `x=4` or a function such as `f(x)=x^2`. |

Built-in evaluation constants include `c` (speed of light), `e`, `pi`, `i`,
`j`, `oo`, `gamma`, `phi`, and common Unicode aliases. The default `c` value is
applied during numeric evaluation; symbolic simplification keeps `c` symbolic
unless you store your own value for it.

---

## Default keymaps

Defaults use `<leader>b`:

| Key | Action |
| --- | --- |
| `<leader>bm` | Open the action menu |
| `<leader>be` | Evaluate |
| `<leader>bs` | Simplify |
| `<leader>br` | Solve |
| `<leader>bd` | Store definition |
| `<leader>bf` | Differentiate |
| `<leader>bp` | Preview |
| `<leader>bl` | List/manage definitions |
| `<leader>bh` | Health check |

Evaluate, simplify, solve, differentiate, define, and preview work in normal and
visual mode. Menu, definition management, and health check are normal-mode
mappings. Existing mappings are not overwritten; a warning is shown instead.

---

## Commands

| Command | Behavior |
| --- | --- |
| `:LatexEval` | Open the action menu. |
| `:LatexEvalEvaluate [expr]` | Evaluate the argument, or detected math when omitted. |
| `:LatexEvalSimplify [expr]` | Simplify the argument, or detected math. |
| `:LatexEvalSolve [variable]` | Solve detected math, optionally for the given variable. |
| `:LatexEvalDifferentiate [variable]` | Differentiate detected math, optionally for the given variable. |
| `:LatexEvalPreview [expr]` | Preview the argument, or detected math. |
| `:LatexEvalDefine [expr]` | Store an argument, or detected math. |
| `:LatexEvalDefine global` | Store detected math in global definitions. |
| `:LatexEvalDefine project` | Store detected math in project-local definitions. |
| `:LatexEvalDefs` | List definitions and delete selected entries. |
| `:LatexEvalInstall` | Install or repair the isolated Python environment. |
| `:LatexEvalHealth` | Report Python version, venv path, dependency versions, imports, and backend status. |

---

## Math detection

In visual mode the selection is used. In normal mode the math surrounding the
cursor is detected.

Supported forms:

```markdown
Inline: $x^2 + 1$

Display: $$x^2 + 1$$

LaTeX delimiters: \(x^2 + 1\) and \[x^2 + 1\]

Environments:
\begin{equation}
x^2 + 1
\end{equation}
```

Supported environments are `equation`, `equation*`, `align`, `align*`, `gather`,
`gather*`, `multline`, and `multline*`. Multiline expressions are supported.

The plugin extracts only the mathematical source. Markdown delimiters are
excluded from the operation and preserved in the buffer. Visual selections that
include delimiters are normalized automatically.

Optional Treesitter detection is enabled by default when a suitable parser is
available. If no math is found, the plugin warns without yanking, changing
registers, or modifying the buffer.

---

## Results and safe replacement

By default, results are shown in a floating window and copied to the `+`
clipboard. The source buffer is not modified automatically.

In the result window:

| Key | Action |
| --- | --- |
| `y` | Copy the result |
| `i` | Insert the displayed result after the source line |
| `r` | Replace the original expression with the raw result |
| `q` / `<Esc>` | Close |

Replacement targets only the expression source range. It preserves:

- `$...$`, `$$...$$`, `\(...\)`, and `\[...\]` delimiters.
- `\begin{...}` / `\end{...}` environment wrappers.
- Indentation before the expression.
- Surrounding prose and other lines.
- Multiline delimiters and environment layout.

For example:

```markdown
The derivative is

$$
f(x) = x^3 + 2x
$$

This concludes the calculation.
```

Differentiating with respect to `x` and pressing `r` changes only the expression:

```markdown
The derivative is

$$
f(x) = 3x^2 + 2
$$

This concludes the calculation.
```

Since this is a normal buffer edit, it is undoable with `u`.

Automatic inline insertion can be enabled:

```lua
require("latex-eval").setup({
  results = {
    inline = true,
    inline_mode = "replace", -- "eol", "below", or "replace"
  },
})
```

---

## Preview

`:LatexEvalPreview` and `<leader>bp` open a simple floating text preview of the
detected expression. This is a source preview, not an image renderer. Your
existing `mdmath.nvim` / Kitty setup remains the rendering system.

Optional text-only Unicode prettification:

```lua
require("latex-eval").setup({
  preview = {
    unicode = true,
  },
})
```

No image rendering backend is included or required.

---

## Stored definitions

Definitions are stored as JSON.

Global file:

```text
stdpath("state")/latex-eval/definitions.json
```

Optional project file:

```text
.latex-eval.json
```

The project file is searched upward from the current buffer directory. If you
store a project definition and no project file exists, it is created next to the
buffer (or in the current working directory when the buffer has no file path).

Project definitions override global definitions without modifying the global
file.

Example definitions file:

```json
{
  "values": {
    "x": "4",
    "a": "\\frac{1}{2}"
  },
  "functions": {
    "f": {
      "variables": ["x"],
      "expression": "x^2"
    }
  }
}
```

Examples:

1. Store `x=4`, then evaluate `$x+1$` to get `5`.
2. Store `f(x)=x^2`, then evaluate `$f(3)$` to get `9`.
3. With `f(x)=x^2`, evaluate `$f(y)$` to get `y^2`.
4. Multi-argument functions such as `g(x,y)=x*y` are supported.
5. Nested user-function calls are expanded safely without executing Python code.

Definitions are applied to evaluate, simplify, solve, and differentiate.

Manage them with `<leader>bl` or `:LatexEvalDefs`. Existing definitions are never
overwritten without confirmation by default.

Definitions are parsed as math, never executed as Python.

---

## Configuration

Call `setup()` with any subset of options:

```lua
require("latex-eval").setup({
  keymaps = {
    enabled = true,
    prefix = "<leader>b",
    mappings = {
      menu = "m",
      evaluate = "e",
      simplify = "s",
      solve = "r",
      define = "d",
      differentiate = "f",
      preview = "p",
      definitions = "l",
      health = "h",
    },
    overrides = {
      -- evaluate = "<leader>E",
    },
  },
  python = {
    cmd = nil,
    system_python = nil,
    venv_path = nil,
    auto_install = true,
    prompt_install = true,
    request_timeout = 30000,
    install_timeout = 300000,
  },
  results = {
    window = true,
    clipboard = true,
    clipboard_register = "+",
    inline = false,
    inline_mode = "eol",
    actions = true,
    max_width = 80,
    max_height = 20,
    border = "rounded",
  },
  preview = {
    unicode = false,
    show_source = false,
    title = "LaTeX preview",
  },
  definitions = {
    enabled = true,
    global_path = nil,
    project_file = ".latex-eval.json",
    project_search = true,
    default_scope = "global",
    ask_scope = false,
    confirm_overwrite = true,
  },
  selection = {
    treesitter = true,
    fallback_to_line = false,
  },
})
```

Disable a single mapping with `mappings.evaluate = false`, or disable all default
mappings with `keymaps.enabled = false`. Use `keymaps.overrides` for full
left-hand-side overrides.

Set `python.cmd` to use an existing Python executable. Automatic installation is
disabled when `python.cmd` is set; that Python must already have the required
modules installed.

---

## Python environment behavior

- The virtual environment is created outside the repository at
  `stdpath("data")/latex-eval/venv`.
- Dependencies are pinned in `python/requirements.txt`.
- `uv` is preferred when it is on `PATH`.
- Otherwise the plugin uses `python3 -m venv` and pip.
- The first operation prompts before installing when dependencies are missing.
- Installation and requests are asynchronous and do not block Neovim's UI.
- Requests use JSON over stdin/stdout; LaTeX is never passed as a raw command
  line argument.
- Stored expressions are never executed as Python code.
- Backend diagnostics go to stderr; stdout is reserved for JSON responses.

---

## API compatibility

The original public API remains available:

```lua
require("latex-eval").evaluate_visual()
require("latex-eval").evaluate_visual(true) -- simplify
require("latex-eval").solve_visual()
require("latex-eval").diff_visual()
```

New public API:

```lua
require("latex-eval").evaluate()
require("latex-eval").simplify()
require("latex-eval").solve()
require("latex-eval").differentiate()
require("latex-eval").define()
require("latex-eval").preview()
require("latex-eval").definitions()
require("latex-eval").menu()
require("latex-eval").health()
require("latex-eval").install()
```

Each new operation can also receive options such as an explicit selection:

```lua
require("latex-eval").evaluate({
  selection = { text = "1+1", kind = "argument" },
})
```

---

## Extending

Add a Python operation:

1. Create `python/latex_eval/operations/<name>.py` with `NAME` and `run(request, engine)`.
2. Register it in `python/latex_eval/operations/__init__.py`.

Add a Lua feature:

1. Create `lua/latex-eval/features/<name>.lua` with `run(selection, options)`.
2. Register it in `lua/latex-eval/features/init.lua`.

---

## Development and tests

Python tests do not require Neovim:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r python/requirements.txt pytest
pytest tests/python
```

Lua files can be syntax-checked with any Lua parser supported by your toolchain.

---

## Troubleshooting

**`:LatexEvalHealth` reports missing Python environment**

Run `:LatexEvalInstall`. If virtual environment creation fails, install
`python3-venv` or `uv`.

**No math detected**

Place the cursor inside the math, or select the math first. Ensure delimiters are
balanced. Enable `selection.fallback_to_line` if you want to operate on the
current non-empty line when no math block is found.

**A solve or differentiate command asks for a variable**

The expression contains more than one unknown symbol. Choose the target, or use
`:LatexEvalSolve x` / `:LatexEvalDifferentiate x`.

**A definition does not take effect**

Check `:LatexEvalDefs`. Project definitions override global definitions. Invalid
JSON files are reported and are not overwritten.

**Replacement removed spacing or delimiters**

The `r` action replaces only the expression source range. It preserves math
delimiters, environment wrappers, indentation, and surrounding prose. If you
selected a custom range, select only the expression source for the most
predictable result.

**Markdown rendering did not update**

`latex-eval.nvim` edits the Markdown buffer directly. Your existing renderer
should update when the buffer changes. The plugin does not create a separate
document or rendering pipeline.