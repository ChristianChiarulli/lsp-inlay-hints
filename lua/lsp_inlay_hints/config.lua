-- vim.cmd([[hi InlayHint guifg=#d8d8d8 guibg=#3a3a3a]]) -- vsc defaults
-- vim.cmd([[hi InlayHint guifg=#8a97c3 guibg=#565F89 ]]) -- vsc eva dark (https://github.com/fisheva/Eva-Theme/blob/b3ca3bc8f3aae4fa174b25cb707b78a4f9ef2d6f/Visual%20Studio/Generate/2022/Eva%20Dark.json)

local function createInlayHintHL()
  local hl = vim.api.nvim_get_hl_by_name("Comment", true)
  local foreground = string.format("#%x", hl["foreground"] or 0)
  if #foreground < 3 then
    foreground = ""
  end

  hl = vim.api.nvim_get_hl_by_name("CursorLine", true)
  local background = string.format("#%x", hl["background"] or 0)
  if #foreground < 3 then
    background = ""
  end

  vim.api.nvim_set_hl(0, "InlayHint", { fg = foreground, bg = background })
end

createInlayHintHL()

local config = {
  options = {
    tools = {
      inlay_hints = {
        only_current_line = false,
        only_current_line_autocmd = "CursorHold",
        show_parameter_hints = true,
        show_variable_name = false,
        parameter_hints_prefix = "<- ",
        -- other_hints_prefix = "=> ",
        -- other_hints_prefix = ": ",
        other_hints_prefix = "",
        max_len_align = false,
        max_len_align_padding = 1,
        right_align = false,
        right_align_padding = 7,
        highlight = "InlayHint",
        -- highlight = "Comment",
      },
    },
  },
}

return config


