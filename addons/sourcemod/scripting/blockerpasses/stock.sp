stock bool GetPlayerEye(int client, float pos[3])
{
	float fAngles[3], fOrigin[3];

	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);

	Handle trace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);

	if (TR_DidHit(trace)) {
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return true;
	}
	CloseHandle(trace);
	return false;
}

stock RotateYaw(float angles[3], float degree)
{
	float fDirection[3], fNormal[3];
	GetAngleVectors(angles, fDirection, NULL_VECTOR, fNormal);

	float sin = Sine(degree * 0.01745328);
	float cos = Cosine(degree * 0.01745328);
	float a = fNormal[0] * sin;
	float b = fNormal[1] * sin;
	float c = fNormal[2] * sin;
	float x = fDirection[2] * b + fDirection[0] * cos - fDirection[1] * c;
	float y = fDirection[0] * c + fDirection[1] * cos - fDirection[2] * a;
	float z = fDirection[1] * a + fDirection[2] * cos - fDirection[0] * b;
	fDirection[0] = x;
	fDirection[1] = y;
	fDirection[2] = z;

	GetVectorAngles(fDirection, angles);

	float fUp[3];
	GetVectorVectors(fDirection, NULL_VECTOR, fUp);

	float fRoll = GetAngleBetweenVectors(fUp, fNormal, fDirection);
	angles[2] += fRoll;
}

stock GetClientAimTarget2(int client, bool only_clients = true)
{
	float fEyeloc[3], fAng[3];
	GetClientEyePosition(client, fEyeloc);
	GetClientEyeAngles(client, fAng);
	TR_TraceRayFilter(fEyeloc, fAng, MASK_SOLID, RayType_Infinite, TRFilter_AimTarget, client);

	int entity = TR_GetEntityIndex();

	if (only_clients) {
		if (entity >= 1 && entity <= MaxClients) {
			return entity;
		}
	} else {
		if (entity > 0) {
			return entity;
		}
	}
	return -1;
}

stock float GetAngleBetweenVectors(const float vector1[3], const float vector2[3], const float fDirection[3])
{
	float fVector1_n[3], fVector2_n[3], fDirection_n[3], fCross[3];
	NormalizeVector(fDirection, fDirection_n);
	NormalizeVector(vector1, fVector1_n);
	NormalizeVector(vector2, fVector2_n);
	float fDegree = ArcCosine(GetVectorDotProduct(fVector1_n, fVector2_n)) * 57.29577951;
	GetVectorCrossProduct(fVector1_n, fVector2_n, fCross);

	if (GetVectorDotProduct(fCross, fDirection_n) < 0.0) {
		fDegree *= -1.0;
	}

	return fDegree;
}

stock void MyGetEntityRenderColor(int entity, int aColor[4])
{
	static bool bGotConfig = false;
	static char sProp[32];

	if (!bGotConfig)
	{
		Handle GameConf = LoadGameConfigFile("core.games");
		bool Exists = GameConfGetKeyValue(GameConf, "m_clrRender", sProp, sizeof(sProp));
		CloseHandle(GameConf);

		if (!Exists)
			strcopy(sProp, sizeof(sProp), "m_clrRender");

		bGotConfig = true;
	}

	int offset = GetEntSendPropOffs(entity, sProp);
	if (offset <= 0) {
		ThrowError("GetEntityColor not supported by this mod");
	}

	for (int i = 0; i < 4; i++)
		aColor[i] = GetEntData(entity, offset + i, 1) & 0xFF;
}

stock SetEntityColor(int entity, int color[4] = {-1, ...})
{
	int dummy_color[4];

	MyGetEntityRenderColor(entity, dummy_color);

	for (int i = 0; i <= 3; i++) {
		if (color[i] != -1) {
			dummy_color[i] = color[i];
		}
	}

	SetEntityRenderColor(entity, dummy_color[0], dummy_color[1], dummy_color[2], dummy_color[3]);
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
}

stock bool StringToColor(const char[] str, int color[4], int defvalue = -1)
{
	bool bResult = false;
	char sSplitter[4][64];
	if (ExplodeString(str, " ", sSplitter, sizeof(sSplitter), sizeof(sSplitter[])) == 4 && String_IsNumeric(sSplitter[0]) && String_IsNumeric(sSplitter[1]) && String_IsNumeric(sSplitter[2]) && String_IsNumeric(sSplitter[3])) {
		color[0] = StringToInt(sSplitter[0]);
		color[1] = StringToInt(sSplitter[1]);
		color[2] = StringToInt(sSplitter[2]);
		color[3] = StringToInt(sSplitter[3]);
		bResult = true;
	} else {
		color[0] = defvalue;
		color[1] = defvalue;
		color[2] = defvalue;
		color[3] = defvalue;
	}
	return bResult;
}

stock ColorToString(const int color[4], char[] buffer, int size)
{
	Format(buffer, size, "%d %d %d %d", color[0], color[1], color[2], color[3]);
}

stock bool String_IsNumeric(const char[] str)
{
	int x = 0;
	int numbersFound = 0;

	if (str[x] == '+' || str[x] == '-') {
		x++;
	}

	while (str[x] != '\0') {
		if (IsCharNumeric(str[x])) {
			numbersFound++;
		} else {
			return false;
		}
		x++;
	}
	if (!numbersFound) {
		return false;
	}
	return true;
}

stock PrintHudText(int client, const char[] text)
{
	Handle hBuffer = StartMessageOne("KeyHintText", client);
	BfWriteByte(hBuffer, 1);
	BfWriteString(hBuffer, text);
	EndMessage();
}