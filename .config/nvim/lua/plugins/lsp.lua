return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- yamlls configured directly, NOT via the lang.yaml extra: the extra injects
        -- SchemaStore schemas via before_init, re-enabling exactly the k8s/kustomize
        -- validation noise deliberately disabled in VSCode (yaml.validate: false).
        -- Completion/hover stay; schema validation stays off.
        yamlls = {
          settings = {
            yaml = {
              validate = false,
              schemaStore = { enable = false, url = "" },
              schemas = {},
            },
          },
        },
        bashls = {},
      },
    },
  },
}
