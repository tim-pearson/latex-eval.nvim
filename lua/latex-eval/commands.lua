local M = {}

local function selection_module()
  return require("latex-eval.selection")
end

local function features()
  return require("latex-eval.features")
end

local function ui()
  return require("latex-eval.ui")
end

local function from_argument(args)
  local text = vim.trim(args or "")
  if text == "" then
    return nil
  end
  return selection_module().from_text(text)
end

local function run_feature(name, selection, options)
  local feature = features().get(name)
  if feature then
    feature.run(selection, options or {})
  end
end

local function scope_completion(argument_lead)
  local values = { "global", "project" }
  local matches = {}
  for _, value in ipairs(values) do
    if value:sub(1, #argument_lead) == argument_lead then
      matches[#matches + 1] = value
    end
  end
  return matches
end

function M.setup()
  vim.api.nvim_create_user_command("LatexEval", function()
    require("latex-eval").menu()
  end, {
    desc = "Open the latex-eval action menu",
  })

  vim.api.nvim_create_user_command("LatexEvalEvaluate", function(command)
    local selected = from_argument(command.args)
      or selection_module().get()
    if selected then
      run_feature("evaluate", selected)
    end
  end, {
    nargs = "*",
    desc = "Evaluate a LaTeX expression (argument or detected math)",
  })

  vim.api.nvim_create_user_command("LatexEvalSimplify", function(command)
    local selected = from_argument(command.args)
      or selection_module().get()
    if selected then
      run_feature("simplify", selected)
    end
  end, {
    nargs = "*",
    desc = "Simplify a LaTeX expression (argument or detected math)",
  })

  vim.api.nvim_create_user_command("LatexEvalSolve", function(command)
    local variable = vim.trim(command.args or "")
    local selected = selection_module().get()
    if selected then
      run_feature("solve", selected, {
        variable = variable ~= "" and variable or nil,
      })
    end
  end, {
    nargs = "?",
    desc = "Solve detected equation, optionally for the given variable",
  })

  vim.api.nvim_create_user_command("LatexEvalDifferentiate", function(command)
    local arguments = vim.split(vim.trim(command.args or ""), "%s+")
    local variable = arguments[1]
    if variable == "" then
      variable = nil
    end
    local order = nil
    if arguments[2] and arguments[2] ~= "" then
      order = tonumber(arguments[2])
      if not order or order < 1 then
        ui().error("Derivative order must be a positive integer")
        return
      end
    end
    local selected = selection_module().get()
    if selected then
      run_feature("differentiate", selected, {
        variable = variable,
        order = order,
      })
    end
  end, {
    nargs = "*",
    desc = "Differentiate detected math, optionally: [variable] [order]",
  })

  vim.api.nvim_create_user_command("LatexEvalDefine", function(command)
    local argument = vim.trim(command.args or "")
    local scope = nil
    local selected = nil
    if argument == "global" or argument == "project" then
      scope = argument
      selected = selection_module().get()
    else
      selected = from_argument(argument) or selection_module().get()
    end
    if selected then
      run_feature("define", selected, { scope = scope })
    end
  end, {
    nargs = "*",
    complete = scope_completion,
    desc = "Store a definition from detected math or as an argument",
  })

  vim.api.nvim_create_user_command("LatexEvalDefs", function()
    require("latex-eval.definitions_buffer").open()
  end, {
    desc = "Edit stored latex-eval definitions in a Markdown buffer",
  })

  vim.api.nvim_create_user_command("LatexEvalJoinMath", function()
    require("latex-eval.transform").join()
  end, {
    desc = "Join separate $$ math blocks into an align* environment",
  })

  vim.api.nvim_create_user_command("LatexEvalSplitMath", function()
    require("latex-eval.transform").split()
  end, {
    desc = "Split an align/gather environment into separate $$ blocks",
  })

  vim.api.nvim_create_user_command("LatexEvalToggleAlign", function()
    require("latex-eval.transform").toggle()
  end, {
    desc = "Toggle between separate $$ blocks and an aligned environment",
  })

  vim.api.nvim_create_user_command("LatexEvalInstall", function()
    require("latex-eval.python").install(function(ok, message)
      if ok then
        ui().info("latex-eval Python environment installed")
      elseif message then
        ui().error(message)
      end
    end)
  end, {
    desc = "Install the isolated latex-eval Python environment",
  })

  vim.api.nvim_create_user_command("LatexEvalHealth", function()
    require("latex-eval.python").health(function(report, ok)
      ui().open_float(report, {
        title = ok and "latex-eval health"
          or "latex-eval health (issues)",
        max_width = 100,
      })
    end)
  end, {
    desc = "Run latex-eval Python and backend health checks",
  })
end

return M