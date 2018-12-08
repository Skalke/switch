#SingleInstance Force

Gui, +Resize
Gui, Add, ListView, vListView Grid r20 w500 gListView, Server|Region|Platform|Delay (MS)
Gui, Show, , Lan-Ping v1.1

Cursor := DllCall("LoadCursor", "UInt", NULL, "Int", 32514, "UInt")
OnMessage(0x200, "WM_MOUSEMOVE")

Loop, Read, % "ServerList.txt"
{
	if (RegExMatch(A_LoopReadLine, "^([^:]+):(\d+)", Match))
	{
		UpdateUI(Match1, Match2)
	}
}

RegExMatch(GetHTTP("http://lan-play.com/"), "js\/app\.[^\.]+\.js", ResponseText)

if (ResponseText)
{
	ResponseText := GetHTTP("http://lan-play.com/" ResponseText)
	
	if (RegExMatch(ResponseText, "\[(?:{[^}]+},?)+\];", ResponseText))
	{
		while (RegExMatch(ResponseText, "{[^}]+}", Match))
		{
			ResponseText := StrReplace(ResponseText, Match, "")
			Server := []
			
			while (RegExMatch(Match, "(\w+):([^,}]+)", JSON))
			{
				Server[ToUpper(JSON1)] := StrReplace(JSON2, """", "")
				Match := StrReplace(Match, JSON, "")
			}
			
			if ((!Server["IP"]) || (!Server["PORT"]) || (Server["ACTIVE"] == "0") || (Server["ACTIVE"] == "!1") || (Server["ACTIVE"] == "false"))
			{
				continue
			}
			
			UpdateUI(Server["IP"], Server["PORT"], Server["FLAG"], Server["PLATFORM"])
		}
	}
}
else
{
	MsgBox, % "ERROR: Unable to fetch server list!"
}

DllCall("DestroyCursor", "Uint", Cursor)
VarSetCapacity(Cursor, 0)

return

WM_MOUSEMOVE(wParam, lParam)
{
	global Cursor
	
	if (Cursor)
	{
		DllCall("SetCursor", "UInt", Cursor)
	}
}

GetHTTP(Address)
{
	WinHttp := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	WinHttp.Open("GET", Address)
	WinHttp.Send()
	
	return WinHttp.ResponseText
}

GetLatency(Address, Port)
{
	AF_INET			:= 2
	SOCK_STREAM		:= 1
	IPPROTO_TCP		:= 6
	
	VarSetCapacity(WsaData, 32)
	Result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0002, "UInt", &WsaData)
	
	if ((ErrorLevel) || (Result))
	{
		return -1
	}
	
	VarSetCapacity(AiHints, 16 + 4 * A_PtrSize, 0)
	
	NumPut(AF_INET, AiHints, 4, "Int")
	NumPut(SOCK_STREAM, AiHints, 8, "Int")
	NumPut(IPPROTO_TCP, AiHints, 12, "Int")
	
	Result := DllCall("Ws2_32\GetAddrInfo", "Ptr", &Address, "Ptr", &Port, "Ptr", &AiHints, "Ptr*", AiResult)
	
	if ((ErrorLevel) || (Result))
	{
		return -1
	}
	
	Result := -1
	Socket := DllCall("Ws2_32\socket", "Int", AF_INET, "Int", SOCK_STREAM, "Int", IPPROTO_TCP)
	TickCount := A_TickCount
	
	if (Socket != -1)
	{
		if (!DllCall("Ws2_32\connect", "UInt", Socket, "UInt", NumGet(AiResult + 0, 16 + 2 * A_PtrSize), "Int", NumGet(AiResult + 0, 16)))
		{
			Result := A_TickCount - TickCount
		}
	}
	
	DllCall("Ws2_32\closesocket", "UInt", Socket)
	DllCall("Ws2_32\FreeAddrInfo", "Ptr", AiResult)
	DllCall("ws2_32\WSACleanup")
	
	return Result
}

GetRegion(Address)
{
	RegExMatch(Address, "^[^:]+", Address)
	RegExMatch(GetHTTP("http://www.geoplugin.net/json.gp?ip=" ResolveHostname(Address)), """" "geoplugin_countryCode" """" ":" """" "([^" """" "]+)" """", Match)
	return Match1 ? Match1 : "?"
}

ResolveHostname(Address)
{
	AF_INET			:= 2
	SOCK_STREAM		:= 1
	IPPROTO_TCP		:= 6
	
	VarSetCapacity(WsaData, 32)
	Result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0002, "UInt", &WsaData)
	
	if ((ErrorLevel) || (Result))
	{
		return -1
	}
	
	VarSetCapacity(AiHints, 16 + 4 * A_PtrSize, 0)
	
	NumPut(AF_INET, AiHints, 4, "Int")
	NumPut(SOCK_STREAM, AiHints, 8, "Int")
	NumPut(IPPROTO_TCP, AiHints, 12, "Int")
	
	Result := DllCall("Ws2_32\GetAddrInfo", "Ptr", &Address, "Ptr", 0, "Ptr", &AiHints, "Ptr*", AiResult)
	
	if ((ErrorLevel) || (Result))
	{
		return -1
	}
	
	Result := DllCall("ws2_32\inet_ntoa", "uint", NumGet(NumGet(AiResult + 0, 16 + 2 * A_PtrSize) + 4, 0, "uint"), "AStr")
	
	DllCall("Ws2_32\FreeAddrInfo", "Ptr", AiResult)
	DllCall("ws2_32\WSACleanup")
	
	return Result
}

ToUpper(Input)
{
	StringUpper, Input, Input
	return Input
}

UpdateUI(Address, Port, Region = "", Platform = "")
{
	Latency := GetLatency(Address, Port)
	
	if (Latency > -1)
	{
		LV_Add("", Address ":" Port, ToUpper(Region ? Region : GetRegion(Address)), Platform ? Platform : "?", Latency)
		
		LV_ModifyCol(1, "AutoHdr")
		LV_ModifyCol(2, "20 AutoHdr")
		LV_ModifyCol(3, "80 AutoHdr")
		LV_ModifyCol(4, "70 Integer Sort")
	}
}

GuiClose:
	DllCall("DestroyCursor", "Uint", Cursor)
	ExitApp

GUISize:
	GuiControl, move, ListView, % "w" (A_GuiWidth - 15) "h" (A_GuiHeight - 15)
	return

ListView:
	global Cursor
	
	if (!Cursor)
	{
		if (A_GuiEvent == "DoubleClick")
		{
			LV_GetText(Server, A_EventInfo)
			InputBox, NULL, % " ", Use CTRL-C to copy the server address to your clipboard., , , 130, , , , , % Server
		}
	}