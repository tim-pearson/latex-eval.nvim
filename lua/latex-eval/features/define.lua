local common = require("latex-eval.features.common")

local M = {}

local function config()
  return require("latex-eval.config").get()
end

local function ui()
  return require("latex-eval.ui")
end

local function store()
  return require("latex-eval.store")
end

local function runner()
  return require("latex-eval.runner")
end

local function choose_scope(options, callback)
  if options.scope == "global" or options.scope == "project" then
    callback(options.scope)
    return
  end
  local settings = config().definitions
  if settings.ask_scope then
    ui().prompt_scope(function(scope)
      if scope then
        callback(scope)
      end
    end)
    return
  end
  callback(settings.default_scope == "project" and "project" or "global")
end

function M.run(selection, options)
  options = options or {}
  local resolved = common.resolve_selection(selection, options)
  if not resolved then
    return
  end

  choose_scope(options, function(scope)
    runner().run({
      operation = "define",
      expression = resolved.text,
    }, function(error, response)
      if error then
        common.handle_error(error, options)
        return
      end

      local definition = response.meta and response.meta.definition
      if not definition then
        ui().error("Backend did not return a definition")
        return
      end

      store().save(definition, scope, function(ok, save_error)
        if not ok then
          if save_error and save_error ~= "cancelled" then
            ui().error("Could not store definition: " .. tostring(save_error))
          end
          return
        end
        common.show(response, resolved, {
          title = "Stored definition (" .. scope .. ")",
        })
      end)
    end)
  end)
end

local function entry_label(entry)
  if entry.kind == "value" then
    return string.format(
      "[%s] value  %s = %s",
      entry.scope,
      entry.name,
      entry.value
    )
  end
  return string.format(
    "[%s] function  %s(%s) = %s",
    entry.scope,
    entry.name,
    table.concat(entry.variables or {}, ", "),
    entry.expression
  )
end

function M.manage()
  local entries = store().list()
  if #entries == 0 then
    ui().info("No stored definitions yet")
    return
  end

  vim.ui.select(entries, {
    prompt = "latex-eval definitions (select one to delete):",
    format_item = entry_label,
  }, function(choice)
    if not choice then
      return
    end
    store().delete(choice.kind, choice.name, choice.scope, function(ok)
      if ok then
        ui().info(
          "Deleted "
            .. choice.kind
            .. " '"
            .. choice.name
            .. "' from "
            .. choice.scope
            .. " definitions"
        )
        M.manage()
      end
    end)
  end)
end

return M