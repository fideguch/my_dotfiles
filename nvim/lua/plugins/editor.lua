return {
  -- Neo-tree: replaces NERDTree
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
        },
      },
      window = {
        width = 30,
      },
    },
  },

  -- Telescope: replaces fzf.vim
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          width = 0.9,
          height = 0.6,
        },
      },
    },
  },
}
