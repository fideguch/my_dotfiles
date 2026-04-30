return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}
    opts.dashboard.preset.header = [[
              ／￣￣＼
             /  ピカチュウ \
            |   ⚡  ⚡   |
             \  ▽  /
              ‾‾|‾‾
              / | \
             /  |  \

       LazyVim with Pokemon Terminal
    ]]
    return opts
  end,
}
