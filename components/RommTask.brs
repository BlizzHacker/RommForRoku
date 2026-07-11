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

    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)

    if m.top.method = "POST" then
        transfer.AddHeader("Content-Type", "application/json")
        started = transfer.AsyncPostFromString(m.top.body)
    else
        started = transfer.AsyncGetToString()
    end if

    ' status 0 means the request never completed (network failure or timeout)
    status = 0
    responseBody = ""
    if started then
        event = wait(30000, port)
        if type(event) = "roUrlEvent" then
            status = event.GetResponseCode()
            responseBody = event.GetString()
        else
            transfer.AsyncCancel()
        end if
    end if

    m.top.response = {
        requestId: m.top.requestId
        status: status
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
