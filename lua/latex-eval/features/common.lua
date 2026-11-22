local M = {}

local function selection_module()
  return require("latex-eval.selection")
end

local function runner()
  return require("latex-eval.runner")
end

local function ui()
  return require("latex-eval.ui")
end

function M.resolve_selection(selection, options)
  if selection then
    return selection
  end
  return selection_module().get({
    notify = not (options and options.silent),
  })
end

function M.handle_error(error, options)
  options = options or {}
  if options.on_error and options.on_error(error) then
    return
  end
  ui().handle_error(error)
end

function M.run(operation, selection, options, on_success)
  options = options or {}
  local resolved = M.resolve_selection(selection, options)
  if not resolved then
    return
  end

  local request = {
    operation = operation,
    expression = resolved.text,
  }
  local operation_options = options.operation_options
  if type(operation_options) == "table" and next(operation_options) ~= nil then
    request.options = operation_options
  end
  if options.variable then
    request.variable = options.variable
  end
  if options.order then
    request.order = options.order
  end

  runner().run(request, function(error, response)
    if error then
      M.handle_error(error, options)
      return
    end
    on_success(response, resolved)
  end, options.runner_options)
end

function M.show(response, selection, options)
  options = options or {}
  ui().show_result(response, {
    title = options.title or "latex-eval",
    selection = selection,
  })
end

return M