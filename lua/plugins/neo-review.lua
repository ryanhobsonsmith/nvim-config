-- STAGED: copy to ~/.config/nvim/lua/plugins/neo-review.lua AFTER the GitHub
-- repo exists (the spec pulls from GitHub; installing before publishing
-- breaks Lazy sync). Then :Lazy install, commit this file + lazy-lock.json.
--
-- neo-review.nvim: in-editor review of (AI-authored) changes — hunk overlay
-- vs a switchable baseline, persisted comment threads agents participate in,
-- and an optional wrapped Claude session driven from review comments.
--
-- The wrapped session's sandbox is Docker Sandboxes (sbx) microVMs and is
-- built into the plugin — same per-project sandboxes the asb wrapper uses,
-- nothing to configure here. Machines without sbx: the agent refuses to
-- start until sbx is installed (or :NeoReviewAgentSandbox off per repo).
-- Review mode and comment threads need no sbx/docker/claude at all.
return {
  {
    "ryanhobsonsmith/neo-review.nvim",
    opts = {
      -- Let external Claude Code sessions act on review comments with zero
      -- per-device setup (symlinks the review-comments skill into
      -- ~/.claude/skills, tracking :Lazy update).
      skill = { auto_install = true },
    },
  },
}
