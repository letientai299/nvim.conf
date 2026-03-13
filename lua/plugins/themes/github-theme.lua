return {
  "projekt0n/github-nvim-theme",
  lazy = true,
  main = "github-theme",
  opts = function()
    return {
      options = {
        dim_inactive = true,
        styles = {
          comments = "italic",
          keywords = "italic",
          functions = "bold",
          types = "bold",
        },
      },
    }
  end,
  themes = {
    "github_dark",
    "github_dark_dimmed",
    "github_dark_high_contrast",
    "github_light",
    "github_light_high_contrast",
  },
}
