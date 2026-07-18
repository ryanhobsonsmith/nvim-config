-- Color filenames in pickers based on their git status, similar to how the
-- file explorer colors modified files. Snacks's `formatters.file.git_status_hl`
-- default only takes effect for items whose `status` field is set, which the
-- regular `files`/`grep`/`buffers` sources don't populate. We attach a
-- `transform` to those sources that looks each entry up in a cached
-- `git status` map and sets `item.filename_hl` directly — the built-in
-- `M.filename` formatter already respects that field.
--
-- The picker transform runs inside a libuv callback (fast context), so it
-- MUST NOT call vim.fn.* or spawn processes. We refresh the cache from
-- ordinary autocmds (VimEnter, BufWritePost, FocusGained, DirChanged) and
-- the transform only reads from the cache.

local uv = vim.uv or vim.loop

---@type { root: string?, paths: table<string, string> }
local cache = { root = nil, paths = {} }

local function refresh()
  -- Always run on the main loop, never inside a fast event.
  vim.schedule(function()
    local cwd = uv.cwd() or "."
    local root_out = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error ~= 0 or not root_out[1] or root_out[1] == "" then
      cache.root = nil
      cache.paths = {}
      return
    end
    local root = root_out[1]
    local lines = vim.fn.systemlist({ "git", "-C", root, "status", "--porcelain=v1", "-uall" })
    local paths = {}
    if vim.v.shell_error == 0 then
      for _, line in ipairs(lines) do
        -- porcelain v1: "XY path"; path starts at column 4
        local xy = line:sub(1, 2)
        local p = line:sub(4)
        -- handle renames "old -> new"
        local _, new = p:match("^(.-) %-> (.+)$")
        if new then
          p = new
        end
        if p ~= "" then
          paths[root .. "/" .. p] = xy
        end
      end
    end
    cache.root = root
    cache.paths = paths
  end)
end

-- Map a git porcelain XY status to a SnacksPickerGitStatus* highlight group.
-- Logic mirrors snacks/picker/source/git.lua's git_status() so colors stay
-- consistent with the explorer / git_status picker.
local function hl_for(xy)
  if xy == "??" then
    return "SnacksPickerGitStatusUntracked"
  end
  if xy == "!!" then
    return "SnacksPickerGitStatusIgnored"
  end
  if xy:find("U") or xy == "AA" or xy == "DD" then
    return "SnacksPickerGitStatusUnmerged"
  end
  local x = xy:sub(1, 1)
  local y = xy:sub(2, 2)
  -- Anything in the index column (other than space/?) means staged.
  if x ~= " " and x ~= "?" then
    return "SnacksPickerGitStatusStaged"
  end
  local names = {
    M = "Modified",
    A = "Added",
    D = "Deleted",
    R = "Renamed",
    C = "Copied",
    T = "Modified",
  }
  return "SnacksPickerGitStatus" .. (names[y] or "Modified")
end

-- Picker transform: read-only cache lookup, safe to call in fast context.
local function git_status_transform(item)
  if not item or not item.file or item.filename_hl then
    return
  end
  if not cache.root then
    return
  end
  local abs = item.file
  if not abs:match("^/") then
    abs = (item.cwd or cache.root) .. "/" .. abs
  end
  local xy = cache.paths[abs]
  if xy then
    item.filename_hl = hl_for(xy)
  end
end

-- Custom file formatter that wraps the built-in one and recolors the
-- directory portion of the path with item.filename_hl, so the *whole* path
-- (not just the basename) reflects git status. Snacks's default formatter
-- hardcodes "SnacksPickerDir" for the directory chunk; we rewrite it.
local function file_format(item, picker)
  local chunks = require("snacks.picker.format").file(item, picker)
  local hl = item.filename_hl
  if not hl then
    return chunks
  end
  for _, chunk in ipairs(chunks) do
    if chunk[2] == "SnacksPickerDir" then
      chunk[2] = hl
    end
    if type(chunk.resolve) == "function" then
      local orig = chunk.resolve
      chunk.resolve = function(max_width)
        local resolved = orig(max_width)
        for _, r in ipairs(resolved or {}) do
          if r[2] == "SnacksPickerDir" then
            r[2] = hl
          end
        end
        return resolved
      end
    end
  end
  return chunks
end

-- Refresh autocmds. Set up at spec-load time so they're live before any
-- picker opens. The initial refresh seeds the cache for the first picker.
local group = vim.api.nvim_create_augroup("snacks_picker_git_status", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "BufWritePost", "DirChanged" }, {
  group = group,
  callback = refresh,
})
refresh()

-- Snacks links SnacksPickerGitStatusUntracked → NonText, the same dim group
-- used for hidden/ignored files, which makes new files hard to distinguish.
-- Override to a more visible color and reapply on every ColorScheme so the
-- override survives colorscheme reloads.
local function apply_hl_overrides()
  vim.api.nvim_set_hl(0, "SnacksPickerGitStatusUntracked", { link = "SnacksPickerGitStatusAdded" })
end
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_hl_overrides })
apply_hl_overrides()

-- Sources that produce file entries and benefit from git-status coloring.
local file_sources = {
  "files",
  "smart",
  "recent",
  "buffers",
  "git_files",
  "grep",
  "grep_word",
  "grep_buffers",
  "lines",
}

local picker_sources = {}
for _, name in ipairs(file_sources) do
  picker_sources[name] = {
    transform = git_status_transform,
    format = file_format,
  }
end

-- Build a list of changed-file absolute paths for the given scope:
--   "working" → modified vs HEAD (staged + unstaged) + untracked
--   "pr"      → everything in "working" plus committed changes vs the PR base
--               (merge-base with origin/HEAD, origin/main, or origin/master)
-- Second return is a short label describing the diff base, for the prompt.
local function sh(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

local function changed_files(scope)
  local seen, files = {}, {}
  local function add(list)
    for _, f in ipairs(list or {}) do
      if f ~= "" and not seen[f] then
        seen[f] = true
        files[#files + 1] = f
      end
    end
  end

  local label
  if scope == "pr" then
    local base
    for _, ref in ipairs({ "origin/HEAD", "origin/main", "origin/master" }) do
      local mb = sh({ "git", "merge-base", "HEAD", ref })
      if mb and mb[1] and mb[1] ~= "" then
        base = mb[1]
        label = ref
        break
      end
    end
    if base then
      add(sh({ "git", "diff", "--name-only", "--diff-filter=d", base }))
    end
  end

  -- Working-tree changes vs HEAD (covers both "working" scope and the
  -- uncommitted portion of "pr" scope, in case HEAD is past the merge-base).
  add(sh({ "git", "diff", "--name-only", "--diff-filter=d", "HEAD" }))
  -- Untracked files (respecting .gitignore).
  add(sh({ "git", "ls-files", "--others", "--exclude-standard" }))

  -- Make paths absolute so the picker resolves them regardless of cwd.
  local root = sh({ "git", "rev-parse", "--show-toplevel" })
  if root and root[1] then
    for i, f in ipairs(files) do
      files[i] = root[1] .. "/" .. f
    end
  end
  return files, label
end

local function grep_changed(scope)
  return function()
    local files, label = changed_files(scope)
    if #files == 0 then
      vim.notify("No changed files found", vim.log.levels.WARN)
      return
    end
    local title
    if scope == "pr" then
      title = string.format("Grep (%d files vs %s)", #files, label or "base")
    else
      title = string.format("Grep (%d uncommitted)", #files)
    end
    -- snacks's grep source feeds `dirs` to rg as positional args; rg accepts
    -- a mix of files and directories, so passing the file list works.
    Snacks.picker.grep({
      dirs = files,
      live = true,
      title = title,
    })
  end
end

-- Saved grep filters. Add a row to "save" a new one; it shows up in the
-- <leader>sf picker automatically. `glob` is passed straight to ripgrep's -g:
-- a positive glob whitelists, a leading ! excludes (later globs win).
local grep_filters = {
  { name = "App code (no test/eval)", glob = { "*.{ts,tsx}", "!*.{test,spec,eval}.*" } },
  { name = "Tests & evals only", glob = { "*.{test,spec,eval}.*" } },
}

-- Live grep restricted to a saved filter's globs (mirrors grep_changed above).
local function grep_filter(filter)
  return function()
    Snacks.picker.grep({
      live = true,
      glob = filter.glob,
      title = "Grep · " .. filter.name,
    })
  end
end

-- <leader>sf entry point: pick a saved filter, then grep with it.
local function pick_grep_filter()
  Snacks.picker.select(grep_filters, {
    prompt = "Grep filter",
    format_item = function(f)
      return f.name
    end,
  }, function(choice)
    if choice then
      grep_filter(choice)()
    end
  end)
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false },
      picker = {
        layout = {
          preset = function()
            return vim.o.columns >= 160 and "default" or "vertical"
          end,
        },
        sources = picker_sources,
      },
      -- Disable Snacks's buffer-local <C-hjkl> t-mode keymaps so the global
      -- smart-splits mappings can fire instead — LazyVim's defaults only do
      -- `wincmd <dir>`, which navigates nvim windows but can't cross into
      -- adjacent tmux panes.
      terminal = {
        win = {
          keys = {
            nav_h = false,
            nav_j = false,
            nav_k = false,
            nav_l = false,
          },
        },
      },
    },
    keys = {
      -- Move Commands / Command History to <leader>sp / <leader>sP (cmd+p style)
      -- so <leader>sc / <leader>sC are free for grep-in-changed-files.
      {
        "<leader>sp",
        function()
          Snacks.picker.commands()
        end,
        desc = "Commands",
      },
      {
        "<leader>sP",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command History",
      },
      {
        "<leader>sc",
        grep_changed("working"),
        desc = "Grep in Uncommitted Files",
      },
      {
        "<leader>sC",
        grep_changed("pr"),
        desc = "Grep in PR Files (vs origin/main)",
      },
      {
        "<leader>sf",
        pick_grep_filter,
        desc = "Grep (filtered)",
      },
    },
  },
}
