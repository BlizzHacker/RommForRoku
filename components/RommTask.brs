sub init()
    m.top.functionName = "executeRequest"
end sub

sub executeRequest()
    transfer = CreateObject("roUrlTransfer")
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(normalizeServer(m.top.server) + m.top.path)
    transfer.AddHeader("Accept", "application/json")

    if m.top.token <> "" then
        transfer.AddHeader("Authorization", "Bearer " + m.top.token)
    end if

    responseBody = ""
    if m.top.method = "POST" then
        transfer.AddHeader("Content-Type", "application/json")
        port = CreateObject("roMessagePort")
        transfer.SetMessagePort(port)
        if transfer.AsyncPostFromString(m.top.body) then
            event = wait(10000, port)
            if type(event) = "roUrlEvent" and event.GetResponseCode() = 200 then
                responseBody = event.GetString()
            end if
        end if
    else
        result = transfer.GetToString()
        if result <> invalid then responseBody = result
    end if

    if responseBody = invalid then responseBody = ""
    m.top.response = {
        requestId: m.top.requestId
        status: 200
        body: responseBody
    }
end sub

function normalizeServer(server as string) as string
    value = server.Trim()
    while value.Len() > 0 and value.Right(1) = "/"
        value = value.Left(value.Len() - 1)
    end while
    return value
end function
