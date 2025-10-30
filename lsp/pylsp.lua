return {
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          ignore = { "W391", "W293" },
          maxLineLength = 200,
        },
      },
    },
  },
}
