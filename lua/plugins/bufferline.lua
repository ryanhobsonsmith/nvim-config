return {
  "akinsho/bufferline.nvim",
  opts = {
    options = {
      -- Hide codediff.nvim virtual buffers so their duplicate filenames don't
      -- trigger bufferline's parent-directory disambiguation on real buffers.
      custom_filter = function(buf)
        return not vim.api.nvim_buf_get_name(buf):match("^codediff://")
      end,
    },
  },
}
