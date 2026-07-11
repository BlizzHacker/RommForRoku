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

    responseBody = invalid
    if m.top.method = "POST" then
        transfer.AddHeader("Content-Type", "application/json")
        responseBody = transfer.PostFromString(m.top.body)
    else
        responseBody = transfer.GetToString()
    end if

    if responseBody = invalid then responseBody = ""
    m.top.response = {
        requestId: m.top.requestId
        status: transfer.GetResponseCode()
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
