local M = {}

local function config()
  return require("latex-eval.config").get()
end

local function ui()
  return require("latex-eval.ui")
end

local actions = {
  {
    label = "Evaluate",
    description = "numeric / symbolic value",
    run = function()
      require("latex-eval").evaluate()
    end,
  },
  {
    label = "Simplify",
    description = "symbolically simplify",
    run = function()
      require("latex-eval").simplify()
    end,
  },
  {
    label = "Solve",
    description = "solve an equation",
    run = function()
      require("latex-eval").solve()
    end,
  },
  {
    label = "Differentiate",
    description = "take a derivative",
    run = function()
      require("latex-eval").differentiate()
    end,
  },
  {
    label = "Store definition",
    description = "remember x=4 or f(x)=x^2",
    run = function()
      require("latex-eval").define()
    end,
  },
  {
    label = "Join / split math",
    description = "toggle aligned multi-line math",
    run = function()
      require("latex-eval").toggle_align()
    end,
  },
  {
    label = "Manage definitions",
    description = "edit stored definitions in a Markdown buffer",
    run = function()
      require("latex-eval").definitions()
    end,
  },
  {
    label = "Install / Health",
    description = "Python environment tools",
    run = function()
      M.open_health()
    end,
  },
}

function M.open_health()
  vim.ui.select({
    "Health check",
    "Install / repair Python environment",
  }, {
    prompt = "latex-eval Python environment:",
  }, function(choice)
    if not choice then
      return
    end
    if choice == "Health check" then
      require("latex-eval.python").health(function(report, ok)
        ui().open_float(report, {
          title = ok and "latex-eval health" or "latex-eval health (issues)",
          max_width = 100,
        })
      end)
      return
    end
    require("latex-eval.python").install(function(ok, message)
      if ok then
        ui().info("latex-eval Python environment installed")
      elseif message then
        ui().error(message)
      end
    end)
  end)
end

function M.open()
  local lines = {}
  local longest = 0
  for index, action in ipairs(actions) do
    lines[index] = string.format(
      "%d. %-20s %s",
      index,
      action.label,
      action.description
    )
    longest = math.max(longest, #lines[index])
  end

  local settings = config().menu
  local max_width = settings.width or 56
  local width = math.min(max_width, math.max(42, longest + 2))
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "latex-eval-menu"

  local ui_size = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local height = #lines
  local row = math.max(0, math.floor((ui_size.height - height) / 2) - 1)
  local col = math.max(0, math.floor((ui_size.width - width) / 2))
  local window = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = settings.border or "rounded",
    title = settings.title or "latex-eval",
    title_pos = "center",
  })

  vim.wo[window].wrap = false
  vim.wo[window].cursorline = true
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].signcolumn = "no"
  vim.wo[window].foldcolumn = "0"
  vim.api.nvim_win_set_cursor(window, { 1, 0 })

  local function close()
    ui().close_float(window)
  end

  local function choose(index)
    local action = actions[index]
    if not action then
      return
    end
    close()
    vim.schedule(function()
      action.run()
    end)
  end

  vim.keymap.set("n", "<CR>", function()
    choose(vim.api.nvim_win_get_cursor(window)[1])
  end, {
    buffer = buffer,
    silent = true,
    nowait = true,
    desc = "Run selected latex-eval action",
  })
  vim.keymap.set("n", "q", close, {
    buffer = buffer,
    silent = true,
    nowait = true,
    desc = "Close latex-eval menu",
  })
  vim.keymap.set("n", "<Esc>", close, {
    buffer = buffer,
    silent = true,
    nowait = true,
    desc = "Close latex-eval menu",
  })
  for index = 1, #actions do
    vim.keymap.set("n", tostring(index), function()
      choose(index)
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Run latex-eval action " .. index,
    })
  end
end

return M