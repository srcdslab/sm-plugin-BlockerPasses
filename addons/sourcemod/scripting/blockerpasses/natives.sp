public void Create_Natives()
{
	CreateNative("sBlockerpasses_IsLocked", Native_GetBpStatusLock);
	
	MarkNativeAsOptional("sBlockerpasses_IsLocked");
}

public int Native_GetBpStatusLock(Handle hPlugin, int iNumParams)
{
	return g_bIsLocked;
}