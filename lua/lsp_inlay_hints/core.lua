-- https://github.com/simrat39/rust-tools.nvim
local M = {}
local utils = require("lsp_inlay_hints.utils")
local config = require("lsp_inlay_hints.config")

function M.setup_autocmd(bufnr, endpoint)
  local events = "BufEnter,BufWinEnter,TabEnter,BufWritePost,CursorHold,InsertLeave"
  if config.options.tools.inlay_hints.only_current_line then
    events = string.format("%s,%s", events, config.options.tools.inlay_hints.only_current_line_autocmd)
  end
  local group = vim.api.nvim_create_augroup("InlayHints", {})
  vim.api.nvim_create_autocmd(vim.split(events, ","), {
    group = group,
    buffer = bufnr,
    callback = function()
      require("lsp_inlay_hints").inlay_hints(endpoint)
    end,
  })
end


local function get_params()
  local params = vim.lsp.util.make_given_range_params()
  params["range"]["start"]["line"] = 0
  params["range"]["end"]["line"] = math.min(vim.api.nvim_buf_line_count(0) - 1, 500)
  return params
end

local namespace = vim.api.nvim_create_namespace("experimental/inlayHints")
local enabled = nil

local function parseHints(result, ctx)
  local map = {}
  local only_current_line = config.options.tools.inlay_hints.only_current_line

  if type(result) ~= "table" then
    return {}
  end

  local client = vim.tbl_filter(function(c)
    return c.id == ctx.client_id
  end, vim.lsp.get_active_clients())[1]

  local is_tsserver = client.name == "tsserver"
  if is_tsserver then
    -- offspec
    if result.inlayHints then
      result = result.inlayHints
    end
  end

  for _, inlayHint in pairs(result) do
    local range = inlayHint.position
    local line = tonumber(inlayHint.position.line)
    if not line then
      vim.api.nvim_notify("Could not parse InlayHint (position.line)", vim.log.levels.WARN)
      goto continue
    end

    local label = inlayHint.label or is_tsserver and inlayHint.text -- offspec
    local kind = inlayHint.kind

    -- offspec
    if type(kind) == "string" then
      kind = (kind == "Parameter" and 2) or 1
    end

    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    local function add_line()
      if not map[line] then
        map[line] = {}
      end

      table.insert(map[line], { label = label, kind = kind, range = range })
    end

    if only_current_line then
      if line == current_line - 1 then
        add_line()
      end
    else
      add_line()
    end

    ::continue::
  end
  return map
end

local function get_max_len(bufnr, parsed_data)
  local max_len = -1

  for line, _ in pairs(parsed_data) do
    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
    if current_line then
      local current_line_len = string.len(current_line)
      max_len = math.max(max_len, current_line_len)
    end
  end

  return max_len
end

local function handler(err, result, ctx)
  if err then
    return
  end

  local opts = config.options.tools.inlay_hints
  local bufnr = ctx.bufnr

  if vim.api.nvim_get_current_buf() ~= bufnr then
    return
  end

  local parsed = parseHints(result, ctx)

  -- clean it up at first
  M.clear_inlay_hints()

  for line, line_hints in pairs(parsed) do
    local virt_text = ""

    local current_line = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
    if current_line then
      local current_line_len = string.len(current_line)

      local param_labels = {}
      local type_hints = {}

      -- segregate parameter hints and other hints
      for _, hint in ipairs(line_hints) do
        if hint.kind == 2 then
          -- label may be a string or InlayHintLabelPart[]
          -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintLabelPart
          if type(hint.label) == "table" then
            local values = vim.tbl_map(function(label_part)
              return label_part.value
            end, hint.label)
            vim.list_extend(param_labels, values)
          else
            table.insert(param_labels, hint.label.value)
          end
        end

        if hint.kind == 1 then
          table.insert(type_hints, hint)
        end
      end

      -- show parameter hints inside brackets with commas and a thin arrow
      if not vim.tbl_isempty(param_labels) and opts.show_parameter_hints then
        virt_text = virt_text .. opts.parameter_hints_prefix .. "("
        for i, label in ipairs(param_labels) do
          virt_text = virt_text .. label:sub(1, -2)
          if i ~= #param_labels then
            virt_text = virt_text .. ", "
          end
        end
        virt_text = virt_text .. ") "
      end

      -- show other hints with commas and a prefix
      if not vim.tbl_isempty(type_hints) then
        virt_text = virt_text .. opts.other_hints_prefix
        local process_virtual_text = function(hint, value)
          local label = value
          if opts.show_variable_name then
            local char_start = hint.range.start.character
            local char_end = hint.range["end"].character
            local variable_name = string.sub(current_line, char_start + 1, char_end)

            virt_text = virt_text .. variable_name .. ": " .. label
          else
            if opts.other_hints_remove_colon then
              -- remove ': ' or ':'
              virt_text = virt_text .. label:match("^:?%s?(.*)$")
            else
              virt_text = virt_text .. label
            end
          end
        end

        for i, hint in ipairs(type_hints) do
          -- label may be a string or InlayHintLabelPart[]
          -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintLabelPart
          if type(hint.label) == "table" then
            for j, label_part in ipairs(hint.label) do
              process_virtual_text(hint, label_part.value)
              if j ~= #hint.label then
                virt_text = virt_text .. ", "
              end
            end
          else
            process_virtual_text(hint, hint.label)
            if i ~= #type_hints then
              virt_text = virt_text .. ", "
            end
          end
        end
      end

      if config.options.tools.inlay_hints.right_align then
        virt_text = virt_text .. string.rep(" ", config.options.tools.inlay_hints.right_align_padding)
      end

      if config.options.tools.inlay_hints.max_len_align then
        local max_len = get_max_len(bufnr, parsed)
        virt_text = string.rep(
          " ",
          max_len - current_line_len + config.options.tools.inlay_hints.max_len_align_padding
        ) .. virt_text
      end

      -- set the virtual text if it is not empty
      if virt_text ~= "" then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
          virt_text_pos = config.options.tools.inlay_hints.right_align and "right_align" or "eol",
          virt_text = {
            { virt_text, config.options.tools.inlay_hints.highlight },
          },
          hl_mode = "combine",
        })
      end

      -- update state
      enabled = true
    end
  end
end

function M.toggle_inlay_hints()
  if enabled then
    M.clear_inlay_hints()
  else
    M.set_inlay_hints()
  end
  enabled = not enabled
end

-- function M.disable_inlay_hints()
--   M.clear_inlay_hints()

--   -- clear then delete
--   local group = vim.api.nvim_create_augroup("InlayHints", {})
--   vim.api.nvim_del_augroup_by_id(group)
--   vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
-- end

function M.clear_inlay_hints()
  -- clear namespace which clears the virtual text as well
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
end

local ctx = {}
local has_changed = function(bufnr)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local saved_tick = ctx[bufnr]
  if saved_tick and saved_tick == tick then
    return false
  end

  ctx[bufnr] = tick

  return true
end

-- Sends the request to get the inlay hints and handle them
function M.set_inlay_hints(endpoint)

  local bufnr = vim.api.nvim_get_current_buf()
  if not has_changed(bufnr) then
    return
  end

  endpoint = endpoint or "textDocument/inlayHint"
  utils.request(bufnr, endpoint, get_params(), handler)
end

-- local debounce_ms = 300
-- _, M.set_inlay_hints = require("user.utils").debounce(M.set_inlay_hints, debounce_ms)

return M


