sub Main(args as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    scene = screen.CreateScene("MainScene")

    ' Deep-link / dev launch: a token (and optional server) passed on the launch
    ' URI lets the channel boot straight into the library without the pairing
    ' screen — e.g. roku ECP /launch/dev?token=...&server=https://romm.example.
    ' MainScene.init picks these up before it decides pair-vs-load.
    if type(args) = "roAssociativeArray" then
        if args.token <> invalid and args.token <> "" then
            scene.launchToken = args.token
        end if
        if args.server <> invalid and args.server <> "" then
            scene.launchServer = args.server
        end if
    end if

    screen.Show()

    while true
        message = wait(0, port)
        if type(message) = "roSGScreenEvent" and message.IsScreenClosed()
            return
        end if
    end while
end sub
