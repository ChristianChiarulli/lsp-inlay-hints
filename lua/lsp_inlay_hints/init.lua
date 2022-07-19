local M = {}

local inlay_hints = require "lsp_inlay_hints.core"
-- local server_status = require "user.lsp.inlay_hints.server_status"
-- local utils = require "user.lsp.inlay_hints.utils"

-- local custom_handlers = {}
--
-- custom_handlers["experimental/serverStatus"] = utils.mk_handler(server_status.handler)

M.inlay_hints = inlay_hints.set_inlay_hints
M.setup_autocmd = inlay_hints.setup_autocmd

return M
