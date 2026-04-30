return {
  "ColaMint/pokemon.nvim",
  cmd = { "PokemonRandom", "PokemonChoose", "PokemonToday" },
  config = function()
    require("pokemon").setup({ number = "random" })
  end,
}
