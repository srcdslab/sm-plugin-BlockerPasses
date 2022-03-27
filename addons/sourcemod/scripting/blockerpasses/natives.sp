public APLRes:AskPluginLoad3(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("sBlockerpasses_IsLocked", Native_GetBpStatusLock);
	
	MarkNativeAsOptional("sBlockerpasses_IsLocked");
	
	return;
}

public Native_GetBpStatusLock(Handle:hPlugin, iNumParams)
{
	return g_bIsLocked;
}