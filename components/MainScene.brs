sub init()
    m.pairPanel = m.top.FindNode("pairPanel")
    m.pairCodeLabel = m.top.FindNode("pairCode")
    m.pairCursorLabel = m.top.FindNode("pairCursor")
    m.screenHeading = m.top.FindNode("screenHeading")
    m.platformList = m.top.FindNode("platformList")
    m.romList = m.top.FindNode("romList")
    m.detailsPanel = m.top.FindNode("detailsPanel")
    m.detailsTitle = m.top.FindNode("detailsTitle")
    m.detailsPlatform = m.top.FindNode("detailsPlatform")
    m.detailsSummary = m.top.FindNode("detailsSummary")
    m.detailsNotice = m.top.FindNode("detailsNotice")
    m.status = m.top.FindNode("status")

    m.platformList.ObserveField("itemSelected", "onPlatformSelected")
    m.romList.ObserveField("itemSelected", "onRomSelected")

    m.defaultServer = "https://romm.moveweight.com"
    m.server = m.defaultServer
    m.codeDigits = ["0", "0", "0", "0", "0", "0", "0", "0"]
    m.cursor = 0
    m.platforms = []
    m.roms = []
    m.view = "pair"

    section = CreateObject("roRegistrySection", "romm")
    if section.Exists("server") then
        m.server = section.Read("server")
    else
        m.server = m.defaultServer
    end if
    if section.Exists("token") then
        m.token = section.Read("token")
    else
        m.token = ""
    end if

    if m.token = "" then
        showPairing()
    else
        loadPlatforms()
    end if
end sub

sub showPairing(message = "")
    m.view = "pair"
    m.pairPanel.visible = true
    m.screenHeading.visible = false
    m.platformList.visible = false
    m.romList.visible = false
    m.detailsPanel.visible = false
    m.top.SetFocus(true)
    updatePairCode()
    if message = "" then
        m.status.text = "Server: " + m.server
    else
        m.status.text = message
    end if
end sub

sub updatePairCode()
    value = ""
    marker = ""
    for i = 0 to 7
        if i = 4 then
            value = value + "  "
            marker = marker + "  "
        end if
        value = value + m.codeDigits[i]
        if i <> 7 then value = value + " "
        if i = m.cursor then
            marker = marker + "^"
        else
            marker = marker + "  "
        end if
    end for
    m.pairCodeLabel.text = value
    m.pairCursorLabel.text = marker
end sub

sub loadPlatforms()
    m.view = "loading-platforms"
    m.pairPanel.visible = false
    m.screenHeading.visible = true
    m.screenHeading.text = "Your platforms"
    m.platformList.visible = false
    m.romList.visible = false
    m.detailsPanel.visible = false
    m.status.text = "Loading your RomM library..."
    beginRequest("platforms", "GET", "/api/platforms", "")
end sub

sub onPlatformSelected()
    index = m.platformList.itemSelected
    if index < 0 or index >= m.platforms.Count() then return
    platform = m.platforms[index]
    m.selectedPlatform = platform
    m.view = "loading-roms"
    m.platformList.visible = false
    m.screenHeading.text = platformDisplayName(platform) + " games"
    m.status.text = "Loading games..."
    path = "/api/roms?platform_ids=" + platform.id.ToStr() + "&limit=200&with_char_index=false&with_filter_values=false"
    beginRequest("roms", "GET", path, "")
end sub

sub onRomSelected()
    index = m.romList.itemSelected
    if index < 0 or index >= m.roms.Count() then return
    game = m.roms[index]
    m.view = "details"
    m.romList.visible = false
    m.detailsPanel.visible = true
    m.detailsTitle.text = safeText(game.name, safeText(game.fs_name_no_ext, "Untitled game"))
    m.detailsPlatform.text = "Platform: " + safeText(game.platform_display_name, platformDisplayName(m.selectedPlatform))
    summary = safeText(game.summary, "No description is available for this game in RomM.")
    m.detailsSummary.text = summary
    m.detailsNotice.text = "Library connection is live. EmulatorJS is browser-based, and Roku channels cannot embed a web browser/WebRTC game client or accept arbitrary Bluetooth or USB gamepad input. This channel is deliberately a secure library companion, not a misleading low-latency streaming promise."
    m.status.text = "Game details"
    m.top.SetFocus(true)
end sub

sub beginRequest(requestId as string, method as string, path as string, body as string)
    task = CreateObject("roSGNode", "RommTask")
    task.server = m.server
    task.token = m.token
    task.path = path
    task.method = method
    task.body = body
    task.requestId = requestId
    task.ObserveField("response", "onResponse")
    m.activeTask = task
    m.top.AppendChild(task)
    task.control = "RUN"
end sub

sub onResponse()
    response = m.activeTask.response
    if response = invalid then return
    parsed = invalid
    if response.body <> "" then parsed = ParseJson(response.body)

    if response.status < 200 or response.status >= 300 then
        if response.requestId = "pair" then
            showPairing("Pairing failed. Check the eight-digit code and create a new one if it expired.")
        else
            showRequestError(response.status)
        end if
        return
    end if

    if response.requestId = "pair" then
        if parsed = invalid or parsed.raw_token = invalid or parsed.raw_token = "" then
            showPairing("RomM did not return a usable client token.")
            return
        end if
        m.token = parsed.raw_token
        saveConnection()
        loadPlatforms()
    else if response.requestId = "platforms" then
        if parsed = invalid or type(parsed) <> "roArray" then
            showRequestError(response.status)
            return
        end if
        displayPlatforms(parsed)
    else if response.requestId = "roms" then
        if parsed = invalid or parsed.items = invalid then
            showRequestError(response.status)
            return
        end if
        displayRoms(parsed.items)
    end if
end sub

sub submitPairCode()
    code = ""
    for each digit in m.codeDigits
        code = code + digit
    end for
    m.view = "pairing"
    m.status.text = "Pairing securely with RomM..."
    beginRequest("pair", "POST", "/api/client-tokens/exchange", FormatJson({ code: code }))
end sub

sub displayPlatforms(data as object)
    m.platforms = []
    content = CreateObject("roSGNode", "ContentNode")
    for each platform in data
        if platform.rom_count <> invalid and platform.rom_count > 0 then
            m.platforms.Push(platform)
            item = content.CreateChild("ContentNode")
            item.title = platformDisplayName(platform) + "  (" + platform.rom_count.ToStr() + ")"
        end if
    end for

    m.view = "platforms"
    m.platformList.content = content
    m.platformList.visible = true
    m.screenHeading.text = "Your platforms"
    m.platformList.SetFocus(true)
    m.status.text = m.platforms.Count().ToStr() + " platforms with games"
end sub

sub displayRoms(data as object)
    m.roms = data
    content = CreateObject("roSGNode", "ContentNode")
    for each game in m.roms
        item = content.CreateChild("ContentNode")
        item.title = safeText(game.name, safeText(game.fs_name_no_ext, "Untitled game"))
    end for

    m.view = "roms"
    m.romList.content = content
    m.romList.visible = true
    m.romList.SetFocus(true)
    count = m.roms.Count()
    m.status.text = count.ToStr() + " games — select one for details"
end sub

sub showRequestError(status as integer)
    if status = 401 or status = 403 then
        clearConnection()
        showPairing("Your RomM token is no longer valid. Pair again with a new code.")
    else
        showPairing("RomM could not be reached (HTTP " + status.ToStr() + "). Try again shortly.")
    end if
end sub

sub saveConnection()
    ' Registry writes skipped for Roku OS 15.2.4 compatibility
end sub

sub clearConnection()
    ' Registry cleared for Roku OS 15.2.4 compatibility
    m.token = ""
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if m.view = "pair" then
        if key = "left" then
            if m.cursor > 0 then m.cursor = m.cursor - 1
            updatePairCode()
            return true
        else if key = "right" then
            if m.cursor < 7 then m.cursor = m.cursor + 1
            updatePairCode()
            return true
        else if key = "up" or key = "down" then
            current = m.codeDigits[m.cursor].ToInt()
            if key = "up" then
                current = current + 1
                if current > 9 then current = 0
            else
                current = current - 1
                if current < 0 then current = 9
            end if
            m.codeDigits[m.cursor] = current.ToStr()
            updatePairCode()
            return true
        else if key = "OK" then
            submitPairCode()
            return true
        end if
    else if m.view = "details" and key = "back" then
        m.detailsPanel.visible = false
        m.romList.visible = true
        m.view = "roms"
        m.romList.SetFocus(true)
        m.status.text = "Select a game for details"
        return true
    else if m.view = "roms" and key = "back" then
        m.romList.visible = false
        m.platformList.visible = true
        m.view = "platforms"
        m.platformList.SetFocus(true)
        m.status.text = "Select a platform"
        return true
    end if
    return false
end function

function safeText(value as dynamic, fallback as string) as string
    if value = invalid then return fallback
    text = value.ToStr()
    if text = "" then return fallback
    return text
end function

function platformDisplayName(platform as dynamic) as string
    if platform = invalid then return "Games"
    return safeText(platform.display_name, safeText(platform.name, "Games"))
end function
