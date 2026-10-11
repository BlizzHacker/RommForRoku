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
    m.searchHint = m.top.FindNode("searchHint")
    m.searchPanel = m.top.FindNode("searchPanel")
    m.searchKeyboard = m.top.FindNode("searchKeyboard")
    m.searchResults = m.top.FindNode("searchResults")

    m.platformList.ObserveField("itemSelected", "onPlatformSelected")
    m.romList.ObserveField("itemSelected", "onRomSelected")
    m.playButton.ObserveField("buttonSelected", "onPlayButton")
    ' Instant search: react to every keystroke in the mini keyboard.
    m.searchKeyboard.ObserveField("text", "onSearchTextChanged")

    ' Default to the LAN address: a self-hosted RomM is normally on the same
    ' network as the Roku, and the public hostname can 500 on the LAN hairpin
    ' path through the reverse proxy. Users on a different network can still pair
    ' against any server via the deep-link server= param or a future settings UI.
    m.defaultServer = "http://192.168.0.94:8080"
    m.streamServer = "http://192.168.0.94:8090"
    m.phoneUrl = "192.168.0.94:8091"
    m.server = m.defaultServer
    ' RomM pairing codes are 8 characters from A-Z (no I, L, O) and 2-9; older
    ' servers issued digits only, so 0-9 stay available. The server strips
    ' hyphens and upper-cases, so what is sent is the bare 8 characters.
    m.codeChars = "0123456789ABCDEFGHJKMNPQRSTUVWXYZ"
    m.codeDigits = ["A", "A", "A", "A", "A", "A", "A", "A"]
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

    ' Deep-link / dev launch: Main() sets launchToken/launchServer on this node,
    ' but it may set them AFTER init() has already run (scene creation is
    ' synchronous). So honor whatever is set now, and also observe the fields so
    ' a slightly-later set from Main() still boots us into the library.
    m.top.ObserveField("launchToken", "onLaunchToken")

    if applyLaunchToken() then return

    if m.token = "" then
        showPairing()
    else
        loadPlatforms()
    end if
end sub

' Returns true if a launch token was applied (and a load kicked off).
function applyLaunchToken() as boolean
    if m.top.launchServer <> invalid and m.top.launchServer <> "" then
        m.server = m.top.launchServer
    end if
    if m.top.launchToken <> invalid and m.top.launchToken <> "" then
        m.token = m.top.launchToken
        saveConnection()
        loadPlatforms()
        return true
    end if
    return false
end function

sub onLaunchToken()
    applyLaunchToken()
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
    ' First ask the stream server which platforms it can actually render on this
    ' host (software cores only - N64/PS1/GC etc. need a GPU and would stream a
    ' black frame). We then show only those, so no game "fails to launch".
    m.streamable = invalid
    beginStreamRequest("streamable", "GET", "/api/play/streamable", "")
end sub

sub onPlatformSelected()
    index = m.platformList.itemSelected
    if index < 0 or index >= m.platforms.Count() then return
    platform = m.platforms[index]
    m.selectedPlatform = platform
    m.searchTerm = ""
    startRomLoad()
end sub

' Begin (or restart) loading the selected platform's ROMs from offset 0.
sub startRomLoad()
    m.view = "loading-roms"
    m.platformList.visible = false
    m.romList.visible = false
    m.roms = []
    m.romOffset = 0
    heading = platformDisplayName(m.selectedPlatform) + " games"
    if m.searchTerm <> invalid and m.searchTerm <> "" then
        heading = heading + " - " + Chr(34) + m.searchTerm + Chr(34)
    end if
    m.screenHeading.text = heading
    m.screenHeading.visible = true
    m.status.text = "Loading games..."
    requestRomPage()
end sub

sub requestRomPage()
    path = "/api/roms?platform_ids=" + m.selectedPlatform.id.ToStr()
    path = path + "&limit=200&offset=" + m.romOffset.ToStr()
    path = path + "&with_files=false&with_char_index=false&with_filter_values=false"
    path = path + "&order_by=name&order_dir=asc"
    if m.searchTerm <> invalid and m.searchTerm <> "" then
        path = path + "&search_term=" + urlEncode(m.searchTerm)
    end if
    beginRequest("roms", "GET", path, "")
end sub

function urlEncode(s as string) as string
    enc = CreateObject("roUrlTransfer")
    return enc.Escape(s)
end function

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
        client: "roku-romm"
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

    if response.requestId = "streamable" then
        ' Build a lookup of slugs the host can render, then load the RomM
        ' platforms. If the stream server is unreachable we fall back to showing
        ' everything rather than an empty screen.
        m.streamable = {}
        if parsed <> invalid and type(parsed.streamable) = "roArray" then
            for each slug in parsed.streamable
                m.streamable[LCase(slug.ToStr())] = true
            end for
        else
            m.streamable = invalid
        end if
        beginRequest("platforms", "GET", "/api/platforms", "")
    else if response.requestId = "stream-start" then
        if parsed <> invalid and parsed.hls_url <> invalid then
            m.streamId = safeText(parsed.stream_id, "")
            m.gameVideo.content = CreateObject("roSGNode", "ContentNode")
            m.gameVideo.content.url = parsed.hls_url
            m.gameVideo.content.streamformat = "hls"
            m.gameVideo.visible = true
            m.gameVideo.control = "play"
            m.gameVideo.SetFocus(true)
            m.streamStatus.text = "Remote: D-pad move  OK = A  Back = exit"
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
        accumulateRomPage(parsed.items)
    end if
end sub

' Append a page of ROMs; if it was full, fetch the next page, else we're done.
sub accumulateRomPage(items as object)
    for each game in items
        m.roms.Push(game)
    end for
    got = items.Count()
    m.romOffset = m.romOffset + got
    ' In search mode a single page of matches is enough - show them immediately
    ' as a filtered list instead of paging the whole platform.
    if m.view = "search" then
        showSearchResults(m.roms)
        return
    end if
    ' Show progress while paging so a big platform doesn't look frozen.
    m.status.text = "Loading games... " + m.roms.Count().ToStr()
    if got >= 200 and m.roms.Count() < 5000 then
        ' Cap at 5000 to bound memory on huge platforms (Amiga has 4400+).
        requestRomPage()
    else
        displayRoms(m.roms)
    end if
end sub

' Render search matches into the results panel + a selectable list.
sub showSearchResults(data as object)
    if data.Count() = 0 then
        m.searchResults.text = "No matches for " + Chr(34) + m.searchTerm + Chr(34)
        return
    end if
    lines = data.Count().ToStr() + " matches:" + Chr(10)
    i = 0
    for each g in data
        if i >= 14 then exit for
        lines = lines + "- " + safeText(g.name, safeText(g.fs_name_no_ext, "?")) + Chr(10)
        i = i + 1
    end for
    m.searchResults.text = lines
    ' also populate the rom list underneath so OK plays the top match
    m.roms = data
    content = CreateObject("roSGNode", "ContentNode")
    for each g in data
        item = content.CreateChild("ContentNode")
        item.title = safeText(g.name, safeText(g.fs_name_no_ext, "?"))
    end for
    m.romList.content = content
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
        hasGames = (platform.rom_count <> invalid and platform.rom_count > 0)
        ' Only show platforms this host can actually render (software cores). If
        ' the streamable list is unavailable, show everything as a fallback.
        canPlay = true
        if m.streamable <> invalid then
            slug = LCase(safeText(platform.slug, ""))
            canPlay = (m.streamable[slug] = true)
        end if
        if hasGames and canPlay then
            m.platforms.Push(platform)
            item = content.CreateChild("ContentNode")
            item.title = platformDisplayName(platform) + "  (" + platform.rom_count.ToStr() + " games)"
        end if
    end for

    m.view = "platforms"
    m.platformList.content = content
    m.platformList.visible = true
    m.screenHeading.text = "Your platforms"
    ' Grab scene focus first: when the channel is deep-linked straight into the
    ' library (no pairing screen), the scene may not hold remote focus yet, so
    ' SetFocus on the list alone leaves ECP/remote keys routed nowhere.
    m.top.SetFocus(true)
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
    m.searchPanel.visible = false
    m.romList.content = content
    m.romList.visible = true
    m.searchHint.visible = true
    m.romList.SetFocus(true)
    m.status.text = m.roms.Count().ToStr() + " games - press * to search"
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
    ' While a game is streaming, the Roku remote drives the emulator directly.
    ' This runs on BOTH press and release so held directions keep moving; all
    ' other views only act on key-down.
    if m.view = "streaming" then
        if key = "back" then
            if press then stopGameStream()
            return true
        end if
        control = remoteToGameControl(key)
        if control <> "" then
            sendGameInput(control, press)
            return true
        end if
        return false
    end if

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
            current = Instr(1, m.codeChars, m.codeDigits[m.cursor]) - 1
            if current < 0 then current = 0
            total = Len(m.codeChars)
            if key = "up" then
                current = current + 1
                if current >= total then current = 0
            else
                current = current - 1
                if current < 0 then current = total - 1
            end if
            m.codeDigits[m.cursor] = Mid(m.codeChars, current + 1, 1)
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
    else if m.view = "roms" and (key = "options" or key = "info" or key = "asterisk") then
        openSearch()
        return true
    else if m.view = "roms" and key = "back" then
        m.romList.visible = false
        m.searchHint.visible = false
        m.platformList.visible = true
        m.platformList.SetFocus(true)
        m.view = "platforms"
        m.screenHeading.text = "Your platforms"
        m.status.text = "Select a platform"
        return true
    else if m.view = "search" and key = "back" then
        closeSearch()
        return true
    end if
    return false
end function

' ---- instant search ----
sub openSearch()
    m.view = "search"
    m.romList.visible = false
    m.searchHint.visible = false
    m.searchPanel.visible = true
    m.searchKeyboard.text = ""
    m.searchResults.text = "Start typing to search " + platformDisplayName(m.selectedPlatform) + "..."
    m.searchKeyboard.SetFocus(true)
end sub

sub closeSearch()
    m.searchPanel.visible = false
    m.searchTerm = ""
    ' reload the full (unsearched) list
    startRomLoad()
end sub

' Every keystroke re-queries the server with search_term. RomM's search is fast
' and we pull only the first page, so results feel instant.
sub onSearchTextChanged()
    term = m.searchKeyboard.text
    m.searchTerm = term
    if term = "" then
        m.searchResults.text = "Start typing to search..."
        return
    end if
    m.searchResults.text = "Searching " + Chr(34) + term + Chr(34) + " ..."
    m.romOffset = 0
    m.roms = []
    ' a fresh single-page query with the term; results land in accumulateRomPage,
    ' which (when in search view) fills the results label instead of the list.
    requestRomPage()
end sub

' Map a Roku remote button to an emulator control (server maps these to the
' EmulatorJS/RetroArch keys per platform). Runs during a streaming session.
function remoteToGameControl(key as string) as string
    if key = "up" then return "up"
    if key = "down" then return "down"
    if key = "left" then return "left"
    if key = "right" then return "right"
    if key = "OK" then return "a"
    if key = "options" then return "b"
    if key = "instantreplay" then return "x"
    if key = "info" then return "y"
    if key = "rewind" then return "select"
    if key = "fastforward" then return "start"
    if key = "play" then return "start"
    return ""
end function

sub sendGameInput(control as string, pressed as boolean)
    if m.streamId = invalid or m.streamId = "" then return
    if m.inputTasks = invalid then m.inputTasks = []
    body = FormatJson({ key: control, pressed: pressed })
    task = CreateObject("roSGNode", "RommTask")
    task.server = m.streamServer
    task.token = ""
    task.path = "/api/stream/" + m.streamId + "/input"
    task.method = "POST"
    task.body = body
    task.requestId = "input"
    task.ObserveField("response", "onInputDone")
    m.inputTasks.Push(task)
    task.control = "RUN"
end sub

sub onInputDone(evt as object)
    node = evt.GetRoSGNode()
    for i = 0 to m.inputTasks.Count() - 1
        if m.inputTasks[i].isSameNode(node) then
            m.inputTasks.Delete(i)
            return
        end if
    end for
end sub

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
