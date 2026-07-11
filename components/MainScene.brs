sub init()
    m.pairPanel = m.top.FindNode("pairPanel")
    m.pairCodeLabel = m.top.FindNode("pairCode")
    m.pairCursorLabel = m.top.FindNode("pairCursor")
    m.screenHeading = m.top.FindNode("screenHeading")
    m.platformList = m.top.FindNode("platformList")
    m.romList = m.top.FindNode("romList")
    m.detailsPanel = m.top.FindNode("detailsPanel")
    m.detailsCover = m.top.FindNode("detailsCover")
    m.detailsTitle = m.top.FindNode("detailsTitle")
    m.detailsPlatform = m.top.FindNode("detailsPlatform")
    m.detailsSummary = m.top.FindNode("detailsSummary")
    m.detailsPlayHint = m.top.FindNode("detailsPlayHint")
    m.gameVideo = m.top.FindNode("gameVideo")
    m.streamStatus = m.top.FindNode("streamStatus")
    m.status = m.top.FindNode("status")
    m.playButton = m.top.FindNode("playButton")

    m.platformList.ObserveField("itemSelected", "onPlatformSelected")
    m.romList.ObserveField("itemSelected", "onRomSelected")
    m.playButton.ObserveField("buttonSelected", "onPlayButton")

    m.defaultServer = "https://romm.moveweight.com"
    m.streamServer = "http://192.168.0.94:8090"
    m.phoneUrl = "192.168.0.94:8091"
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
    m.gameVideo.visible = false
    m.streamStatus.visible = false
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
    m.gameVideo.visible = false
    m.streamStatus.visible = false
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
    path = "/api/roms?platform_ids=" + platform.id.ToStr() + "&limit=500&with_char_index=false&with_filter_values=false"
    beginRequest("roms", "GET", path, "")
end sub

sub onRomSelected()
    index = m.romList.itemSelected
    if index < 0 or index >= m.roms.Count() then return
    game = m.roms[index]
    m.selectedGame = game
    m.view = "details"
    m.romList.visible = false
    m.detailsPanel.visible = true
    if game.id <> invalid then
        m.detailsCover.uri = m.server + "/api/roms/" + game.id.ToStr() + "/cover"
    else
        m.detailsCover.uri = ""
    end if
    m.detailsTitle.text = safeText(game.name, safeText(game.fs_name_no_ext, "Untitled game"))
    m.detailsPlatform.text = "Platform: " + safeText(game.platform_display_name, platformDisplayName(m.selectedPlatform))
    m.detailsSummary.text = safeText(game.summary, "No description available.")
    m.detailsPlayHint.text = "Phone: " + m.phoneUrl
    m.status.text = "Game details"
    m.playButton.SetFocus(true)
end sub

sub onPlayButton()
    startGameStream()
end sub

sub startGameStream()
    if m.selectedGame = invalid then return
    game = m.selectedGame
    m.view = "streaming"
    m.detailsPanel.visible = false
    m.streamStatus.visible = true
    m.streamStatus.text = "Starting stream..."
    m.status.text = "Launching " + safeText(game.name, "game")

    body = FormatJson({
        name: safeText(game.name, "game")
        platform: safeText(m.selectedPlatform.slug, "n64")
        rom_name: safeText(game.fs_name, "")
    })
    beginStreamRequest("stream-start", "POST", "/api/stream/start", body)
end sub

sub stopGameStream()
    m.gameVideo.control = "stop"
    m.gameVideo.visible = false
    m.streamStatus.visible = false
    m.view = "details"
    m.detailsPanel.visible = true
    m.playButton.SetFocus(true)
    m.status.text = "Stream ended"
    if m.streamId <> invalid and m.streamId <> "" then
        beginStreamRequest("stream-stop", "POST", "/api/stream/" + m.streamId + "/stop", "")
        m.streamId = ""
    end if
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
    task.control = "RUN"
end sub

sub beginStreamRequest(requestId as string, method as string, path as string, body as string)
    task = CreateObject("roSGNode", "RommTask")
    task.server = m.streamServer
    task.token = ""
    task.path = path
    task.method = method
    task.body = body
    task.requestId = requestId
    task.ObserveField("response", "onStreamResponse")
    m.streamTask = task
    task.control = "RUN"
end sub

sub onStreamResponse(event as object)
    response = event.GetData()
    if response = invalid then return
    parsed = invalid
    if response.body <> "" then parsed = ParseJson(response.body)
    if type(parsed) <> "roAssociativeArray" then parsed = invalid

    if response.requestId = "stream-start" then
        if parsed <> invalid and parsed.hls_url <> invalid then
            m.streamId = safeText(parsed.stream_id, "")
            m.gameVideo.content = CreateObject("roSGNode", "ContentNode")
            m.gameVideo.content.url = parsed.hls_url
            m.gameVideo.content.streamformat = "hls"
            m.gameVideo.visible = true
            m.gameVideo.control = "play"
            m.streamStatus.text = "Phone: " + m.phoneUrl + "/?sid=" + m.streamId
        else
            m.streamStatus.text = "Stream failed"
            m.status.text = "Could not start game stream"
        end if
    else if response.requestId = "stream-stop" then
        m.streamStatus.text = ""
    end if
end sub

sub onResponse(event as object)
    response = event.GetData()
    if response = invalid then return
    parsed = invalid
    if response.body <> "" then parsed = ParseJson(response.body)

    if response.status < 200 or response.status >= 300 then
        if response.requestId = "pair" then
            showPairing("Pairing failed. Check the code and create a new one if it expired.")
        else
            showRequestError(response.status)
        end if
        return
    end if

    if response.requestId = "pair" then
        if type(parsed) <> "roAssociativeArray" or parsed.raw_token = invalid or parsed.raw_token = "" then
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
        if type(parsed) <> "roAssociativeArray" or parsed.items = invalid then
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
            item.title = platformDisplayName(platform) + "  (" + platform.rom_count.ToStr() + " games)"
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
    m.status.text = m.roms.Count().ToStr() + " games — select one for details"
end sub

sub showRequestError(status as integer)
    if status = 401 or status = 403 then
        clearConnection()
        showPairing("Your RomM token is no longer valid. Pair again with a new code.")
    else if status <= 0 then
        showPairing("Could not reach RomM. Check your network and try again.")
    else
        showPairing("RomM could not be reached (HTTP " + status.ToStr() + "). Try again shortly.")
    end if
end sub

sub saveConnection()
    section = CreateObject("roRegistrySection", "romm")
    section.Write("server", m.server)
    section.Write("token", m.token)
    section.Flush()
end sub

sub clearConnection()
    section = CreateObject("roRegistrySection", "romm")
    section.Delete("token")
    section.Flush()
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
    else if m.view = "details" and key = "OK" then
        startGameStream()
        return true
    else if m.view = "details" and (key = "Play" or key = "play") then
        startGameStream()
        return true
    else if m.view = "streaming" and key = "back" then
        stopGameStream()
        return true
    else if m.view = "roms" and key = "back" then
        m.romList.visible = false
        m.platformList.visible = true
        m.platformList.SetFocus(true)
        m.view = "platforms"
        m.screenHeading.text = "Your platforms"
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
