local actions = require'telescope.actions'
local action_set = require'telescope.actions.set'
local action_state = require'telescope.actions.state'
local conf = require'telescope.config'.values
local entry_display = require'telescope.pickers.entry_display'
local finders = require'telescope.finders'
local from_entry = require'telescope.from_entry'
local pickers = require'telescope.pickers'
local previewers = require'telescope.previewers.term_previewer'
local utils = require'telescope.utils'
local Path = require('plenary.path')

local os_home = vim.loop.os_homedir()

local M = {}

local function gen_from_z(opts)
  local displayer = entry_display.create{
    separator = ' ',
    items = {
      {width = 7, right_justify = true}, -- score
      {remaining = true}, -- path
    },
  }

  local function make_display(entry)
    local dir = (function(path)
      if path == Path.path.root() then return path end

      local p = Path:new(path)
      if opts.tail_path then
        local parts = p:_split()
        return parts[#parts]
      end

      if opts.shorten_path then return p:shorten() end

      if vim.startswith(path, opts.cwd) and path ~= opts.cwd then
        return Path:new(p):make_relative(opts.cwd)
      end

      if vim.startswith(path, os_home) then
        return (Path:new'~' / p:make_relative(os_home)).filename
      end
      return path
    end)(entry.path)

    return displayer{
      {('%.2f'):format(entry.value), 'TelescopeResultsIdentifier'},
      dir,
    }
  end

  return function(line)
    local score_str, dir = line:match'([%.%d]+)%s+(.+)'
    local score = tonumber(score_str)

    return {
      value = score,
      ordinal = dir,
      path = dir,
      display = make_display,
    }
  end
end

M.list = function(opts)
  opts = opts or {}
  local cmd = vim.F.if_nil(opts.cmd, {vim.o.shell, '-c', 'z -l'})
  opts.cwd = utils.get_lazy_default(opts.cwd, vim.loop.cwd)
  opts.entry_maker = utils.get_lazy_default(opts.entry_maker, gen_from_z, opts)

  pickers.new(opts, {
    prompt_title = 'Visited directories from z',
    finder = finders.new_table{
      results = utils.get_os_command_output(cmd),
      entry_maker = opts.entry_maker,
    },
    sorter = conf.file_sorter(opts),
    previewer = previewers.cat.new(opts),
    mappings = opts.mappings,
    attach_mappings = function(prompt_bufnr)
      action_set.select:replace(function(_, type)
        local entry = action_state.get_selected_entry()
        local dir = from_entry.path(entry)
        action_set.edit(prompt_bufnr, action_state.select_key_to_edit_key(type))
      end)
      return true
    end,
  }):find()
end

return M
