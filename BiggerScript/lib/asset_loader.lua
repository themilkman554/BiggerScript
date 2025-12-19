--------------------------------------------------------------------------------
-- Asset Loader Library for BiggerScript
-- Handles downloading and updating assets from GitHub repositories
--------------------------------------------------------------------------------

local AssetLoader = {}

-- Configuration
local menuRootPath = FileMgr.GetMenuRootPath()
local defaultTargetPath = menuRootPath .. "\\Lua\\BiggerScript"

--------------------------------------------------------------------------------
-- Simple JSON Parser (Pure Lua) to avoid external dependencies
--------------------------------------------------------------------------------
local function json_decode(text)
    local pos = 1
    local function skip_whitespace()
        while pos <= #text and text:sub(pos, pos):match("%s") do pos = pos + 1 end
    end
    local function parse_value()
        skip_whitespace()
        local char = text:sub(pos, pos)
        if char == "{" then
            pos = pos + 1
            local obj = {}
            skip_whitespace()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while true do
                local key = parse_value()
                skip_whitespace()
                if text:sub(pos, pos) == ":" then pos = pos + 1 else return nil end
                local val = parse_value()
                obj[key] = val
                skip_whitespace()
                local next_char = text:sub(pos, pos)
                pos = pos + 1
                if next_char == "}" then return obj end
                if next_char ~= "," then return nil end
            end
        elseif char == "[" then
            pos = pos + 1
            local arr = {}
            skip_whitespace()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return arr end
            local idx = 1
            while true do
                arr[idx] = parse_value()
                idx = idx + 1
                skip_whitespace()
                local next_char = text:sub(pos, pos)
                pos = pos + 1
                if next_char == "]" then return arr end
                if next_char ~= "," then return nil end
            end
        elseif char == '"' then
            local start = pos + 1
            local end_quote = text:find('"', start)
            while end_quote and text:sub(end_quote-1, end_quote-1) == '\\' do
                end_quote = text:find('"', end_quote + 1)
            end
            if not end_quote then return nil end
            local str = text:sub(start, end_quote - 1)
            pos = end_quote + 1
            return str
        elseif char == "t" then pos = pos + 4; return true
        elseif char == "f" then pos = pos + 5; return false
        elseif char == "n" then pos = pos + 4; return nil
        else
            local start = pos
            while pos <= #text and text:sub(pos, pos):match("[%d%.%-eE+]") do pos = pos + 1 end
            return tonumber(text:sub(start, pos - 1))
        end
    end
    if not text then return nil end
    return parse_value()
end

AssetLoader.json_decode = json_decode

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, data, mode)
    local f = io.open(path, mode or "w")
    if f then
        f:write(data or "")
        f:close()
        return true
    end
    return false
end

--- Ensures all parent directories exist for a given file path using FileMgr.CreateDir
---@param path string The full file path
local function ensure_dir(path)
    local dir = path:match("(.+)[/\\]")
    if dir then
        -- Use FileMgr.CreateDir to create the directory (and all parent directories)
        FileMgr.CreateDir(dir)
    end
end

--- Makes an HTTP GET request using Curl
---@param url string The URL to fetch
---@return string|nil The response body or nil on failure
local function curl_get(url)
    local curl = Curl.Easy()
    curl:Setopt(10002, url)  -- CURLOPT_URL
    curl:Setopt(52, 1)       -- CURLOPT_FOLLOWLOCATION
    curl:Setopt(10018, "Cherax-Script")  -- CURLOPT_USERAGENT
    curl:Perform()
    while not curl:GetFinished() do
        Script.Yield(10)
    end
    local code, response = curl:GetResponse()
    if code == 0 then return response end
    return nil
end

-- Expose helper functions
AssetLoader.read_file = read_file
AssetLoader.write_file = write_file
AssetLoader.ensure_dir = ensure_dir
AssetLoader.curl_get = curl_get

--------------------------------------------------------------------------------
-- Asset Management Functions
--------------------------------------------------------------------------------

--- Configuration for an asset repository
---@class AssetConfig
---@field owner string GitHub repository owner
---@field repo string GitHub repository name
---@field branch string Branch name (default: "main")
---@field targetPath string Local path to store assets
---@field lastCommitFile string Path to store the last commit SHA
---@field showToasts boolean Whether to show toast notifications (default: true)
---@field toastTitle string Title for toast notifications (default: "AssetLoader")

--- Creates a new asset configuration
---@param owner string GitHub repository owner
---@param repo string GitHub repository name
---@param targetPath string|nil Local path to store assets (optional)
---@param branch string|nil Branch name (optional, default: "main")
---@return AssetConfig
function AssetLoader.createConfig(owner, repo, targetPath, branch)
    targetPath = targetPath or defaultTargetPath
    return {
        owner = owner,
        repo = repo,
        branch = branch or "main",
        targetPath = targetPath,
        lastCommitFile = targetPath .. "\\last_commit.txt",
        showToasts = true,
        toastTitle = "AssetLoader"
    }
end

--- Gets the latest commit SHA from a repository
---@param config AssetConfig The asset configuration
---@return string|nil The latest commit SHA or nil on failure
function AssetLoader.getLatestCommit(config)
    local api_url = string.format("https://api.github.com/repos/%s/%s/commits/%s", 
        config.owner, config.repo, config.branch)
    local body = curl_get(api_url)
    local commit_data = json_decode(body)
    return commit_data and commit_data.sha
end

--- Gets the locally stored commit SHA
---@param config AssetConfig The asset configuration
---@return string|nil The stored commit SHA or nil if not found
function AssetLoader.getStoredCommit(config)
    return read_file(config.lastCommitFile)
end

--- Saves the commit SHA locally
---@param config AssetConfig The asset configuration
---@param sha string The commit SHA to save
function AssetLoader.saveCommit(config, sha)
    ensure_dir(config.lastCommitFile)
    write_file(config.lastCommitFile, sha)
end

--- Performs a full installation by downloading and extracting the entire repository
---@param config AssetConfig The asset configuration
---@param callback function|nil Optional callback function(success, message)
function AssetLoader.fullInstall(config, callback)
    if config.showToasts then
        GUI.AddToast(config.toastTitle, "Installing assets...", 5000, 0)
    end
    
    local ZIP_URL = string.format("https://codeload.github.com/%s/%s/zip/refs/heads/%s",
        config.owner, config.repo, config.branch)
    local tempZipPath = menuRootPath .. "\\Lua\\AssetLoaderTemp.zip"
    
    local zipData = curl_get(ZIP_URL)
    if zipData then
        write_file(tempZipPath, zipData, "wb")
        if FileMgr.Unzip(tempZipPath, menuRootPath .. "\\Lua") then
            FileMgr.DeleteFile(tempZipPath)
            local extractedFolder = menuRootPath .. "\\Lua\\" .. config.repo .. "-" .. config.branch
            
            -- Backup existing folder if it exists
            if FileMgr.DoesFileExist(config.targetPath) then
                local backupPath = config.targetPath .. "_backup_" .. os.time()
                os.rename(config.targetPath, backupPath)
            end
            os.rename(extractedFolder, config.targetPath)
            
            local latest_commit = AssetLoader.getLatestCommit(config)
            if latest_commit then 
                AssetLoader.saveCommit(config, latest_commit)
            end
            
            if config.showToasts then
                GUI.AddToast(config.toastTitle, "Assets Installed!", 5000, 0)
            end
            if callback then callback(true, "Assets installed successfully") end
        else
            if config.showToasts then
                GUI.AddToast(config.toastTitle, "Failed to unzip assets!", 5000, 0)
            end
            if callback then callback(false, "Failed to unzip assets") end
        end
    else
        if config.showToasts then
            GUI.AddToast(config.toastTitle, "Asset Download Failed!", 5000, 0)
        end
        if callback then callback(false, "Asset download failed") end
    end
end

--- Performs an incremental update by downloading only changed files
---@param config AssetConfig The asset configuration  
---@param lastCommit string The last known commit SHA
---@param latestCommit string The latest commit SHA
---@param callback function|nil Optional callback function(success, message, updatedFiles)
function AssetLoader.incrementalUpdate(config, lastCommit, latestCommit, callback)
    if config.showToasts then
        GUI.AddToast(config.toastTitle, "Updating Assets...", 5000, 0)
    end
    
    -- Use GitHub compare API to get all commits between last and latest
    local compare_url = string.format("https://api.github.com/repos/%s/%s/compare/%s...%s", 
        config.owner, config.repo, lastCommit, latestCommit)
    local compare_body = curl_get(compare_url)
    local compare_data = json_decode(compare_body)
    
    if compare_data and compare_data.files then
        local count = 0
        local added_files = {}
        local removed_files = {}
        
        for _, file in ipairs(compare_data.files) do
            local filename = file.filename
            local status = file.status
            local raw_url = file.raw_url
            local local_path = config.targetPath .. "\\" .. filename:gsub("/", "\\")
            
            if status == "removed" then
                if FileMgr.DoesFileExist(local_path) then
                    FileMgr.DeleteFile(local_path)
                    table.insert(removed_files, filename)
                end
            elseif status == "added" or status == "modified" then
                local content = curl_get(raw_url)
                if content then
                    -- Use FileMgr.CreateDir to ensure directory exists
                    ensure_dir(local_path)
                    write_file(local_path, content, "wb") -- binary safe
                    count = count + 1
                    table.insert(added_files, filename)
                end
            end
        end
        
        AssetLoader.saveCommit(config, latestCommit)
        
        -- Build toast message with all added files
        local toast_msg = "Updated " .. count .. " files."
        if #added_files > 0 then
            toast_msg = toast_msg .. "\n"
            for i, filename in ipairs(added_files) do
                toast_msg = toast_msg .. "\n" .. filename
            end
        end
        
        if config.showToasts then
            GUI.AddToast(config.toastTitle, toast_msg, 5000, 0)
        end
        
        if callback then 
            callback(true, toast_msg, {added = added_files, removed = removed_files})
        end
    else
        if config.showToasts then
            GUI.AddToast(config.toastTitle, "Failed to parse update data.", 5000, 0)
        end
        if callback then callback(false, "Failed to parse update data") end
    end
end

--- Checks for updates and applies them if available
---@param config AssetConfig The asset configuration
---@param callback function|nil Optional callback function(updateType, success, message)
---@return boolean Whether an update check was initiated
function AssetLoader.checkAndUpdate(config, callback)
    local latest_commit = AssetLoader.getLatestCommit(config)
    local last_commit = AssetLoader.getStoredCommit(config)
    
    -- Determine Update Strategy
    if not FileMgr.DoesFileExist(config.targetPath) or not last_commit then
        -- Full Install (Missing folder or no version history)
        AssetLoader.fullInstall(config, function(success, message)
            if callback then callback("full_install", success, message) end
        end)
        return true
    elseif latest_commit and latest_commit ~= last_commit then
        -- Incremental Update
        AssetLoader.incrementalUpdate(config, last_commit, latest_commit, function(success, message, files)
            if callback then callback("incremental", success, message, files) end
        end)
        return true
    else
        -- Already up to date
        if callback then callback("up_to_date", true, "Assets are up to date") end
        return false
    end
end

--- Runs the asset check and update in a queued job (non-blocking)
---@param config AssetConfig The asset configuration
---@param callback function|nil Optional callback function(updateType, success, message)
function AssetLoader.checkAndUpdateAsync(config, callback)
    Script.QueueJob(function()
        AssetLoader.checkAndUpdate(config, callback)
    end)
end

--------------------------------------------------------------------------------
-- File Download Utilities
--------------------------------------------------------------------------------

--- Downloads a single file from a URL
---@param url string The URL to download from
---@param localPath string The local path to save the file
---@param createDirs boolean|nil Whether to create parent directories (default: true)
---@return boolean Whether the download was successful
function AssetLoader.downloadFile(url, localPath, createDirs)
    if createDirs ~= false then
        ensure_dir(localPath)
    end
    
    local content = curl_get(url)
    if content then
        return write_file(localPath, content, "wb")
    end
    return false
end

--- Downloads a raw file from a GitHub repository
---@param owner string GitHub repository owner
---@param repo string GitHub repository name
---@param branch string Branch name
---@param filePath string Path to the file within the repository
---@param localPath string The local path to save the file
---@return boolean Whether the download was successful
function AssetLoader.downloadGitHubFile(owner, repo, branch, filePath, localPath)
    local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s",
        owner, repo, branch, filePath)
    return AssetLoader.downloadFile(url, localPath)
end

--------------------------------------------------------------------------------
-- Default BiggerScript Assets Configuration
--------------------------------------------------------------------------------

--- Creates the default configuration for BiggerScript assets
---@return AssetConfig
function AssetLoader.getBiggerScriptAssetsConfig()
    local config = AssetLoader.createConfig("themilkman554", "BiggerScriptAssests")
    config.toastTitle = "BiggerScript"
    return config
end

--- Convenience function to update BiggerScript assets
---@param callback function|nil Optional callback function
function AssetLoader.updateBiggerScriptAssets(callback)
    local config = AssetLoader.getBiggerScriptAssetsConfig()
    AssetLoader.checkAndUpdateAsync(config, callback)
end

return AssetLoader
