local M = {}

local ALLOWED_ENVIRONMENTS = {
  equation = true,
  ["equation*"] = true,
  align = true,
  ["align*"] = true,
  gather = true,
  ["gather*"] = true,
  multline = true,
  ["multline*"] = true,
  displaymath = true,
}

local function config()
  return require("latex-eval.config").get()
end

local function notify_missing()
  require("latex-eval.ui").warn(
    "No LaTeX math expression found at the cursor or in the visual selection"
  )
end

local function trim(value)
  return vim.trim(value or "")
end

local function is_escaped(line, index)
  local cursor = index - 1
  local backslashes = 0
  while cursor >= 1 and line:sub(cursor, cursor) == "\\" do
    backslashes = backslashes + 1
    cursor = cursor - 1
  end
  return backslashes % 2 == 1
end

local function exit_visual()
  if
    vim.fn.mode() == "v"
    or vim.fn.mode() == "V"
    or vim.fn.mode() == "\22"
  then
    pcall(vim.cmd, "normal! \27")
  end
end

local function position_after(start_row, start_col, prefix)
  local newlines = 0
  local last_newline = 0
  for index = 1, #prefix do
    if prefix:sub(index, index) == "\n" then
      newlines = newlines + 1
      last_newline = index
    end
  end
  if newlines == 0 then
    return start_row, start_col + #prefix
  end
  return start_row + newlines, #prefix - last_newline
end

local function range_for_content(start_row, start_col, content)
  local newlines = 0
  local last_newline = 0
  for index = 1, #content do
    if content:sub(index, index) == "\n" then
      newlines = newlines + 1
      last_newline = index
    end
  end
  if newlines == 0 then
    return {
      start_row = start_row,
      start_col = start_col,
      end_row = start_row,
      end_col = start_col + #content,
    }
  end
  return {
    start_row = start_row,
    start_col = start_col,
    end_row = start_row + newlines,
    end_col = #content - last_newline,
  }
end

local function copy_selection(selection)
  local result = {}
  for key, value in pairs(selection) do
    result[key] = value
  end
  return result
end

local function selection_with_prefix(selection, prefix_bytes, content)
  local result = copy_selection(selection)
  result.text = content
  if selection.range then
    local prefix = selection.text:sub(1, prefix_bytes)
    local start_row, start_col = position_after(
      selection.range.start_row,
      selection.range.start_col,
      prefix
    )
    result.range = range_for_content(start_row, start_col, content)
  end
  return result
end

local function trim_selection(selection)
  local text = selection.text or ""
  local leading = #(text:match("^%s*") or "")
  local trailing = #(text:match("%s*$") or "")
  local content = text:sub(leading + 1, #text - trailing)
  if content == "" then
    return selection
  end
  return selection_with_prefix(selection, leading, content)
end

local function strip_math_delimiters(selection)
  local text = selection.text or ""
  local leading = #(text:match("^%s*") or "")
  local trailing = #(text:match("%s*$") or "")
  local trimmed = text:sub(leading + 1, #text - trailing)
  local open_length = 0
  local close_length = 0

  if
    #trimmed >= 4
    and trimmed:sub(1, 2) == "$$"
    and trimmed:sub(-2) == "$$"
  then
    open_length = 2
    close_length = 2
  elseif
    #trimmed >= 2
    and trimmed:sub(1, 1) == "$"
    and trimmed:sub(-1) == "$"
  then
    open_length = 1
    close_length = 1
  elseif trimmed:sub(1, 2) == "\\[" and trimmed:sub(-2) == "\\]" then
    open_length = 2
    close_length = 2
  elseif trimmed:sub(1, 2) == "\\(" and trimmed:sub(-2) == "\\)" then
    open_length = 2
    close_length = 2
  else
    local environment = trimmed:match("^\\begin{([^}]+)}")
    if environment then
      local open_marker = "\\begin{" .. environment .. "}"
      local close_marker = "\\end{" .. environment .. "}"
      if trimmed:sub(-#close_marker) == close_marker then
        open_length = #open_marker
        close_length = #close_marker
      end
    end
  end

  if open_length == 0 then
    return selection
  end

  local content = trimmed:sub(open_length + 1, #trimmed - close_length)
  return selection_with_prefix(selection, leading + open_length, content)
end

function M.normalize(selection)
  if not selection then
    return nil
  end
  local normalized = strip_math_delimiters(selection)
  normalized = trim_selection(normalized)
  if trim(normalized.text) == "" then
    return nil
  end
  return normalized
end

local function visual_selection()
  local mode = vim.fn.mode()
  if not (mode == "v" or mode == "V" or mode == "\22") then
    return nil
  end

  local start_position = vim.fn.getpos("v")
  local end_position = vim.fn.getpos(".")
  local text = nil
  local range = nil

  local region_ok, region = pcall(
    vim.fn.getregion,
    start_position,
    end_position,
    { type = mode }
  )
  if region_ok and type(region) == "table" then
    text = table.concat(region, "\n")
    local start_row = start_position[2]
    local start_col = start_position[3]
    local end_row = end_position[2]
    local end_col = end_position[3]
    if
      start_row > end_row
      or (start_row == end_row and start_col > end_col)
    then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
    end

    if mode == "V" then
      local last_line = vim.api.nvim_buf_get_lines(
        0,
        end_row - 1,
        end_row,
        false
      )[1] or ""
      range = {
        start_row = start_row - 1,
        start_col = 0,
        end_row = end_row - 1,
        end_col = #last_line,
        linewise = true,
      }
    else
      range = {
        start_row = start_row - 1,
        start_col = start_col - 1,
        end_row = end_row - 1,
        end_col = end_col,
      }
    end
  end

  if not text then
    local register = vim.fn.getreg('"')
    local register_type = vim.fn.getregtype('"')
    local ok = pcall(vim.cmd, "silent normal! y")
    if ok then
      text = vim.fn.getreg('"')
    end
    pcall(vim.fn.setreg, '"', register, register_type)
  end

  exit_visual()

  if not text or trim(text) == "" then
    return nil
  end

  return { text = text, range = range, kind = "visual" }
end

local function find_in_line(line, delimiter, from_col)
  local position = line:find(delimiter, from_col + 1, true)
  while position do
    local valid = not is_escaped(line, position)
    local previous = position > 1 and line:sub(position - 1, position - 1) or ""
    local current = line:sub(position, position + #delimiter - 1)
    if delimiter == "$" and (current == "$$" or previous == "$") then
      valid = false
    end
    if delimiter == "$$" and previous == "$" then
      valid = false
    end
    if valid then
      return position - 1
    end
    position = line:find(delimiter, position + 1, true)
  end
  return nil
end

local function find_delimiter(lines, delimiter, start_row, start_col)
  for row = start_row, #lines - 1 do
    local line = lines[row + 1] or ""
    local from_col = row == start_row and start_col or 0
    local column = find_in_line(line, delimiter, from_col)
    if column then
      return { row = row, col = column }
    end
  end
  return nil
end

local function content_for(lines, open_position, close_position, open, close)
  local start_row = open_position.row
  local start_col = open_position.col + #open
  local end_row = close_position.row
  local end_col = close_position.col

  if start_row == end_row then
    local line = lines[start_row + 1] or ""
    return line:sub(start_col + 1, end_col), {
      start_row = start_row,
      start_col = start_col,
      end_row = end_row,
      end_col = end_col,
    }
  end

  local content = {}
  content[#content + 1] = (lines[start_row + 1] or ""):sub(start_col + 1)
  for row = start_row + 1, end_row - 1 do
    content[#content + 1] = lines[row + 1] or ""
  end
  content[#content + 1] = (lines[end_row + 1] or ""):sub(1, end_col)
  return table.concat(content, "\n"), {
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

local function cursor_inside(open_position, close_position, row, col)
  local after_open = row > open_position.row
    or (row == open_position.row and col >= open_position.col)
  local before_close = row < close_position.row
    or (row == close_position.row and col <= close_position.col)
  return after_open and before_close
end

local function find_pair(lines, row, col, open, close, options)
  options = options or {}
  local search_row = 0
  local search_col = 0

  while search_row < #lines do
    local open_position =
      find_delimiter(lines, open, search_row, search_col)
    if not open_position then
      return nil
    end

    local close_position = find_delimiter(
      lines,
      close,
      open_position.row,
      open_position.col + #open
    )

    if not close_position then
      return nil
    end

    if options.same_line and close_position.row ~= open_position.row then
      search_row = open_position.row
      search_col = open_position.col + 1
    else
      if cursor_inside(open_position, close_position, row, col) then
        local text, range = content_for(
          lines,
          open_position,
          close_position,
          open,
          close
        )
        if trim(text) ~= "" then
          return {
            text = text,
            range = range,
            kind = options.kind or "delimiter",
          }
        end
      end
      search_row = close_position.row
      search_col = close_position.col + #close
    end
  end

  return nil
end

local function detect_environment(lines, row, col)
  local best = nil
  local best_span = math.huge

  for start_row = 0, #lines - 1 do
    local line = lines[start_row + 1] or ""
    local search = 1
    while true do
      local begin_start, begin_end, environment =
        line:find("\\begin{([^}]+)}", search)
      if not begin_start then
        break
      end

      if ALLOWED_ENVIRONMENTS[environment] then
        local end_marker = "\\end{" .. environment .. "}"
        local end_row = nil
        local end_start = nil
        for candidate_row = start_row, #lines - 1 do
          local candidate_line = lines[candidate_row + 1] or ""
          local from = candidate_row == start_row and begin_end + 1 or 1
          local found, found_end = candidate_line:find(end_marker, from, true)
          if found then
            end_row = candidate_row
            end_start = found
            local end_col = found_end
            break
          end
        end

        if end_row then
          local inside_row = row >= start_row and row <= end_row
          local inside = inside_row
          if inside and start_row == end_row then
            local content_start = begin_end
            local content_end = end_start - 1
            inside = col >= content_start and col <= content_end
          end

          if inside then
            local span = end_row - start_row
            if span <= best_span then
              local content = nil
              local range = nil
              local content_start_col = begin_end
              local content_end_col = end_start - 1
              if start_row == end_row then
                content = line:sub(begin_end + 1, end_start - 1)
                range = {
                  start_row = start_row,
                  start_col = content_start_col,
                  end_row = end_row,
                  end_col = content_end_col,
                }
              else
                local parts = {}
                parts[#parts + 1] = (lines[start_row + 1] or ""):sub(
                  begin_end + 1
                )
                for content_row = start_row + 1, end_row - 1 do
                  parts[#parts + 1] = lines[content_row + 1] or ""
                end
                parts[#parts + 1] = (lines[end_row + 1] or ""):sub(
                  1,
                  end_start - 1
                )
                content = table.concat(parts, "\n")
                range = {
                  start_row = start_row,
                  start_col = content_start_col,
                  end_row = end_row,
                  end_col = content_end_col,
                }
              end

              if trim(content) ~= "" then
                best = {
                  text = content,
                  range = range,
                  kind = "environment",
                  environment = environment,
                }
                best_span = span
              end
            end
          end
        end
      end

      search = begin_end + 1
    end
  end

  return best
end

local function treesitter_detection(bufnr, row, col)
  if not config().selection.treesitter then
    return nil
  end
  if not vim.treesitter or not vim.treesitter.get_node then
    return nil
  end

  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = bufnr,
    pos = { row, col },
  })
  if not ok or not node then
    return nil
  end

  while node do
    local node_type = node:type()
    local is_math = node_type:match("math")
      or node_type:match("equation")
      or node_type:match("formula")
      or node_type == "latex_block"
      or node_type == "latex_inline"
    if is_math then
      local start_row, start_col, end_row, end_col = node:range()
      local text = vim.treesitter.get_node_text(node, bufnr)
      if trim(text) ~= "" then
        return {
          text = text,
          range = {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
          },
          kind = "treesitter",
          node_type = node_type,
        }
      end
    end
    node = node:parent()
  end

  return nil
end

function M.detect_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local treesitter = treesitter_detection(bufnr, row, col)
  if treesitter then
    return M.normalize(treesitter)
  end

  local environment = detect_environment(lines, row, col)
  if environment then
    return M.normalize(environment)
  end

  local display_pairs = {
    { open = "$$", close = "$$", kind = "display" },
    { open = "\\[", close = "\\]", kind = "display" },
    { open = "\\(", close = "\\)", kind = "inline" },
  }
  for _, pair in ipairs(display_pairs) do
    local found = find_pair(
      lines,
      row,
      col,
      pair.open,
      pair.close,
      { kind = pair.kind }
    )
    if found then
      return M.normalize(found)
    end
  end

  local inline = find_pair(
    lines,
    row,
    col,
    "$",
    "$",
    { kind = "inline", same_line = true }
  )
  if inline then
    return M.normalize(inline)
  end

  return nil
end

function M.get_visual_raw()
  return visual_selection()
end

function M.get(options)
  options = options or {}
  local selection = visual_selection()
  if selection then
    return M.normalize(selection)
  end

  selection = M.detect_at_cursor()
  if selection then
    return M.normalize(selection)
  end

  if config().selection.fallback_to_line then
    local line = vim.api.nvim_get_current_line()
    if trim(line) ~= "" then
      return M.normalize({
        text = line,
        range = {
          start_row = vim.api.nvim_win_get_cursor(0)[1] - 1,
          start_col = 0,
          end_row = vim.api.nvim_win_get_cursor(0)[1] - 1,
          end_col = #line,
        },
        kind = "line",
      })
    end
  end

  if options.notify ~= false then
    notify_missing()
  end
  return nil
end

function M.from_text(text)
  if not text or trim(text) == "" then
    return nil
  end
  return { text = trim(text), kind = "argument" }
end

function M.strip_math_delimiters(text)
  local value = trim(text)
  if #value >= 4 and value:sub(1, 2) == "$$" and value:sub(-2) == "$$" then
    return trim(value:sub(3, -3))
  end
  if #value >= 2 and value:sub(1, 1) == "$" and value:sub(-1) == "$" then
    return trim(value:sub(2, -2))
  end
  if value:sub(1, 2) == "\\[" and value:sub(-2) == "\\]" then
    return trim(value:sub(3, -3))
  end
  if value:sub(1, 2) == "\\(" and value:sub(-2) == "\\)" then
    return trim(value:sub(3, -3))
  end
  local environment, content =
    value:match("^\\begin{([^}]+)}(.*)\\end{%1}$")
  if environment and content then
    return trim(content)
  end
  return value
end

return M