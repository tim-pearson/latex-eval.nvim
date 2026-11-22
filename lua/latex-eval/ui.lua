local M = {}

local function config()
  return require("latex-eval.config").get()
end

function M.notify(message, level, options)
  options = options or {}
  local settings = config()
  if settings.notifications.enabled == false and not options.force then
    return
  end
  vim.notify(
    message,
    level or settings.notifications.level or vim.log.levels.INFO,
    { title = options.title or "latex-eval" }
  )
end

function M.info(message, options)
  M.notify(message, vim.log.levels.INFO, options)
end

function M.warn(message, options)
  M.notify(message, vim.log.levels.WARN, options)
end

function M.error(message, options)
  M.notify(message, vim.log.levels.ERROR, options)
end

function M.handle_error(error)
  if type(error) == "table" and error.message then
    M.error(error.message)
  else
    M.error(tostring(error))
  end
end

local function split_lines(value)
  if type(value) == "table" then
    return value
  end
  return vim.split(tostring(value or ""), "\n", { plain = true })
end

function M.close_float(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

function M.open_float(content, options)
  options = options or {}
  local lines = split_lines(content)
  if #lines == 0 then
    lines = { "" }
  end

  local max_width = math.max(tonumber(options.max_width) or 80, 20)
  local max_height = math.max(tonumber(options.max_height) or 20, 1)
  local width = 20
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
  end
  width = math.min(width, max_width)
  local height = math.min(math.max(#lines, 1), max_height)

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = options.filetype or "tex"

  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local row = math.max(0, math.floor((ui.height - height) / 2) - 1)
  local col = math.max(0, math.floor((ui.width - width) / 2))

  local window_options = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = options.border or "rounded",
  }
  if options.title and options.title ~= "" then
    window_options.title = options.title
    window_options.title_pos = options.title_pos or "center"
  end

  local window = vim.api.nvim_open_win(buffer, true, window_options)
  vim.wo[window].wrap = options.wrap ~= false
  vim.wo[window].linebreak = true
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].cursorline = false
  vim.wo[window].signcolumn = "no"
  vim.wo[window].foldcolumn = "0"
  vim.wo[window].spell = false

  local close_key = options.close_key or "q"
  if close_key and close_key ~= "" then
    vim.keymap.set("n", close_key, function()
      M.close_float(window)
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Close latex-eval window",
    })
  end
  vim.keymap.set("n", "<Esc>", function()
    M.close_float(window)
  end, {
    buffer = buffer,
    silent = true,
    nowait = true,
    desc = "Close latex-eval window",
  })

  return buffer, window
end

local function replace_range(buffer, range, text)
  local lines = vim.split(text, "\n", { plain = true })
  local start_row = math.min(range.start_row, range.end_row)
  local end_row = math.max(range.start_row, range.end_row)
  local start_col = range.start_col or 0
  local end_col = range.end_col or 0

  if start_row == end_row and start_col > end_col then
    start_col, end_col = end_col, start_col
  end

  if #lines == 1 then
    vim.api.nvim_buf_set_text(
      buffer,
      start_row,
      start_col,
      end_row,
      end_col,
      lines
    )
  else
    vim.api.nvim_buf_set_lines(
      buffer,
      start_row,
      end_row + 1,
      false,
      lines
    )
  end
end

function M.apply_inline(text, options)
  options = options or {}
  local settings = config().results
  local buffer = options.bufnr or 0
  local mode = options.inline_mode or settings.inline_mode or "eol"
  local selection = options.selection
  local range = selection and selection.range or nil

  if mode == "replace" then
    if not range then
      M.warn("Cannot replace because no source range is available")
      return false
    end
    replace_range(buffer, range, text)
    return true
  end

  local cursor = vim.api.nvim_win_get_cursor(options.win or 0)
  local row = range and range.end_row or (cursor[1] - 1)

  if mode == "below" then
    local lines = vim.split(text, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(buffer, row + 1, row + 1, false, lines)
    return true
  end

  local lines = vim.split(text, "\n", { plain = true })
  local current = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]
    or ""
  lines[1] = current .. " " .. lines[1]
  vim.api.nvim_buf_set_lines(buffer, row, row + 1, false, lines)
  return true
end

local function closing_math_line(line, from_col)
  local trimmed = vim.trim(line)
  if trimmed == "$$" or trimmed == "\\]" or trimmed == "\\)" then
    return true
  end
  if trimmed:match("^\\end{") then
    return true
  end
  local rest = from_col and line:sub(from_col + 1) or line
  return rest:find("$$", 1, true) ~= nil
    or rest:find("\\)", 1, true) ~= nil
    or rest:find("\\]", 1, true) ~= nil
    or rest:find("\\end{", 1, true) ~= nil
end

local function insert_row_after_math(buffer, selection)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local end_row = #lines - 1
  local end_col = nil
  if selection and selection.range then
    end_row = selection.range.end_row
    end_col = selection.range.end_col
  else
    end_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  end

  local line = lines[end_row + 1] or ""
  if closing_math_line(line, end_col) then
    return end_row
  end

  local scan = end_row + 1
  while scan < #lines do
    local candidate = lines[scan + 1] or ""
    if vim.trim(candidate) == "" then
      scan = scan + 1
    else
      if closing_math_line(candidate) then
        return scan
      end
      break
    end
  end
  return end_row
end

function M.insert_math_block(text, selection, bufnr)
  local buffer = bufnr or 0
  local row = insert_row_after_math(buffer, selection)
  local content = vim.split(tostring(text or ""), "\n", { plain = true })
  local block = { "", "$$" }
  for _, line in ipairs(content) do
    block[#block + 1] = line
  end
  block[#block + 1] = "$$"
  vim.api.nvim_buf_set_lines(buffer, row + 1, row + 1, false, block)
  return row + 3
end

function M.show_result(response, options)
  options = options or {}
  local settings = config().results
  local source_win = options.win or vim.api.nvim_get_current_win()
  local source_buf = options.bufnr or vim.api.nvim_win_get_buf(source_win)
  local display = response
  local result = response
  local kind = nil
  local meta = {}
  if type(response) == "table" then
    display = response.display or response.result or ""
    result = response.result or display
    kind = response.kind
    meta = type(response.meta) == "table" and response.meta or {}
  end
  display = tostring(display or "")
  result = tostring(result or "")
  local whole = display
  local right = tostring(meta.rhs or meta.right or result or display)
  local replace_full = tostring(
    meta.replace_full or meta.replacement or result or display
  )
  local replace_rhs = tostring(
    meta.replace_rhs or meta.replace or meta.replacement or result or display
  )
  local block_text = tostring(meta.replace_full or result or display)
  if display == "" then
    M.warn("The backend returned an empty result")
    return
  end

  local title = options.title or "latex-eval"
  if kind and kind ~= "" then
    title = title .. " [" .. kind .. "]"
  end

  local buffer = nil
  local window = nil
  if settings.window ~= false then
    local float_lines = split_lines(display)
    if settings.show_help ~= false and settings.actions then
      float_lines[#float_lines + 1] = ""
      float_lines[#float_lines + 1] =
        "y copy | Y copy rhs | i insert | r replace | R replace rhs | a append block | q close"
    end
    buffer, window = M.open_float(float_lines, {
      title = title,
      border = settings.border,
      title_pos = settings.title_pos,
      max_width = settings.max_width,
      max_height = settings.max_height,
      close_key = settings.close_key,
      filetype = "tex",
    })
  else
    M.info(display, { force = true })
  end

  local function copy(value)
    if settings.clipboard ~= false then
      local register = settings.clipboard_register or "+"
      pcall(vim.fn.setreg, register, value)
    end
  end

  copy(right)

  if settings.actions and buffer then
    local function close()
      M.close_float(window)
    end

    vim.keymap.set("n", "y", function()
      copy(right)
      pcall(vim.fn.setreg, '"', replacement)
      M.info("Copied result")
      close()
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Copy latex-eval result",
    })

    vim.keymap.set("n", "i", function()
      local ok, error_message = pcall(M.apply_inline, display, {
        selection = options.selection,
        inline_mode = "eol",
        bufnr = source_buf,
        win = source_win,
      })
      if ok then
        close()
      else
        M.warn("Could not insert result: " .. tostring(error_message))
      end
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Insert latex-eval result",
    })

    vim.keymap.set("n", "r", function()
      local selection = options.selection
      if not selection or not selection.range then
        M.warn("No source range is available for replacement")
        return
      end
      local ok, error_message = pcall(M.apply_inline, replace_full, {
        selection = selection,
        inline_mode = "replace",
        bufnr = source_buf,
        win = source_win,
      })
      if ok then
        M.info("Replaced the source with the full result")
        close()
      else
        M.warn("Could not replace expression: " .. tostring(error_message))
      end
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Replace source with the full latex-eval result",
    })

    vim.keymap.set("n", "a", function()
      local row = M.insert_math_block(
        block_text,
        options.selection,
        source_buf
      )
      pcall(vim.api.nvim_win_set_cursor, source_win, { row + 1, 0 })
      M.info("Added a new math block below")
      close()
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Add result as a new math block below",
    })

    vim.keymap.set("n", "R", function()
      local selection = options.selection
      if not selection or not selection.range then
        M.warn("No source range is available for replacement")
        return
      end
      local ok, error_message = pcall(M.apply_inline, replace_rhs, {
        selection = selection,
        inline_mode = "replace",
        bufnr = source_buf,
        win = source_win,
      })
      if ok then
        M.info("Replaced the source right-hand side")
        close()
      else
        M.warn("Could not replace expression: " .. tostring(error_message))
      end
    end, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Replace only the right-hand side of the source",
    })
  end

  if settings.inline then
    local inline_text = settings.inline_mode == "replace" and replace_rhs
      or display
    local ok, error_message = pcall(M.apply_inline, inline_text, {
      selection = options.selection,
      inline_mode = settings.inline_mode,
      bufnr = source_buf,
      win = source_win,
    })
    if not ok then
      M.warn("Could not insert result inline: " .. tostring(error_message))
    end
  end
end

function M.prompt_variable(candidates, callback)
  if candidates and #candidates > 0 then
    vim.ui.select(candidates, {
      prompt = "Choose a variable:",
    }, function(choice)
      callback(choice)
    end)
    return
  end
  vim.ui.input({ prompt = "Variable: " }, function(value)
    callback(value)
  end)
end

function M.prompt_scope(callback)
  vim.ui.select({ "global", "project" }, {
    prompt = "Store definition in:",
  }, function(choice)
    callback(choice)
  end)
end

function M.confirm(message, callback)
  vim.ui.select({ "Yes", "No" }, { prompt = message }, function(choice)
    callback(choice == "Yes")
  end)
end

return M