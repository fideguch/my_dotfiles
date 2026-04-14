-- Read current pokemon from cache
local function get_pokemon_name()
  local poke_file = vim.fn.expand("~/.cache/poke-current")
  if vim.fn.filereadable(poke_file) == 1 then
    local content = vim.fn.readfile(poke_file)
    if #content > 0 and content[1] ~= "" then
      return content[1]
    end
  end
  return "unknown"
end

return {
  -- Bufferline: replaces vim-airline tabline
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },

  -- Disable dashboard-nvim (conflicts with Snacks.dashboard)
  { "nvimdev/dashboard-nvim", enabled = false },

  -- Snacks dashboard: show current Pokemon on startup
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            " ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗",
            " ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║",
            " ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║",
            " ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║",
            " ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║",
            " ╚══════╝╚═╝  ╚═╝╚══════╝  ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝",
            "",
            "                  Current: " .. get_pokemon_name(),
          }, "\n"),
        },
      },
    },
  },
}
