--- @diagnostic disable: undefined-field
local uv = vim.uv or vim.loop
local api = vim.api
local lsp = vim.lsp

local function format_all_lua_files_sync (client)
  local root = client.config.root_dir
  if not root then return end

  --- Recursively gather all *.lua files
  local function scan_dir (dir, results)
    local fs = uv.fs_scandir (dir)
    if not fs then return end

    while true do
      local name, type = uv.fs_scandir_next (fs)
      if not name then break end
      local full_path = vim.fs.joinpath (dir, name)

      if type == "file" and name:match ("%.lua$") then
        table.insert (results, full_path)
      elseif type == "directory" then
        scan_dir (full_path, results)
      end
    end
  end

  local files = {}
  scan_dir (root, files)

  --- Synchronous step-by-step formatting
  local function format_next (index)
    local file = files[index]
    if not file then
      local success = true
      for _, buf in ipairs (files) do
        if type (buf) ~= "number" then
          success = false
        else
          api.nvim_buf_delete (buf, { force = true })
        end
      end
      if success then
        vim.notify ("✅ All Lua files formatted.", vim.log.levels.INFO, { title = "Formatter" })
      else
        vim.notify (
          "❌ Some files could not be formatted.",
          vim.log.levels.ERROR,
          { title = "Formatter" }
        )
      end
      return
    end

    local buf = api.nvim_create_buf (false, true)
    vim.fn.bufload (buf)

    if not lsp.buf_is_attached (buf, client.id) then lsp.buf_attach_client (buf, client.id) end

    -- Format and wait
    api.nvim_buf_call (buf, function ()
      files[index] = buf

      api.nvim_cmd ({
        cmd = "edit",
        args = { file },
        bang = true,
        mods = {
          silent = true,
          emsg_silent = true,
        },
      }, { output = false })

      lsp.buf.format ({ bufnr = buf, name = "lua_ls", async = false })

      api.nvim_cmd ({
        cmd = "write",
        bang = true,
        mods = {
          silent = true,
          emsg_silent = true,
        },
      }, { output = false })

      print ("✨ Formatted ➜ " .. file .. " ✅")
    end)

    vim.defer_fn (function () format_next (index + 1) end, 100) -- slight delay to breathe
  end

  format_next (1)
end

local client = nil
for _, c in ipairs (vim.lsp.get_clients ()) do
  if c.name == "lua_ls" then
    client = c
    break
  end
end

if client == nil then
  vim.notify ("💡 'lua_ls' is not available.", vim.log.levels.ERROR, { title = "Formatter" })
  return
end

format_all_lua_files_sync (client)
