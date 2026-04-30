return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    opts.sections = opts.sections or {}
    opts.sections.lualine_y = {
      { function() return "⚡ " .. os.date("%H:%M") end },
    }
    return opts
  end,
}
