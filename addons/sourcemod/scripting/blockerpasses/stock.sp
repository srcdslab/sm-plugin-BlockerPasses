stock bool GetPlayerEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);

	if(TR_DidHit(trace)){
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return true;
	}
	CloseHandle(trace);
	return false;
}

stock RotateYaw( float angles[3], float degree )
{
    float direction[3], normal[3];
    GetAngleVectors( angles, direction, NULL_VECTOR, normal );
    
    float sin = Sine( degree * 0.01745328 );
    float cos = Cosine( degree * 0.01745328 );
    float a = normal[0] * sin;
    float b = normal[1] * sin;
    float c = normal[2] * sin;
    float x = direction[2] * b + direction[0] * cos - direction[1] * c;
    float y = direction[0] * c + direction[1] * cos - direction[2] * a;
    float z = direction[1] * a + direction[2] * cos - direction[0] * b;
    direction[0] = x;
    direction[1] = y;
    direction[2] = z;
    
    GetVectorAngles( direction, angles );

    float up[3];
    GetVectorVectors( direction, NULL_VECTOR, up );

    float roll = GetAngleBetweenVectors( up, normal, direction );
    angles[2] += roll;
}

stock GetClientAimTarget2(int client, bool only_clients = true)
{
    float eyeloc[3], ang[3];
    GetClientEyePosition(client, eyeloc);
    GetClientEyeAngles(client, ang);
    TR_TraceRayFilter(eyeloc, ang, MASK_SOLID, RayType_Infinite, TRFilter_AimTarget, client);
	
    int entity = TR_GetEntityIndex();

    if (only_clients){
        if (entity >= 1 && entity <= MaxClients){
            return entity;
		}
    }else{
        if (entity > 0){
            return entity;
		}
    }
    return -1;
}

stock float GetAngleBetweenVectors( const float vector1[3], const float vector2[3], const float direction[3] )
{
    float vector1_n[3], vector2_n[3], direction_n[3], cross[3];
    NormalizeVector( direction, direction_n );
    NormalizeVector( vector1, vector1_n );
    NormalizeVector( vector2, vector2_n );
    float degree = ArcCosine( GetVectorDotProduct( vector1_n, vector2_n ) ) * 57.29577951;
    GetVectorCrossProduct( vector1_n, vector2_n, cross );
    
    if ( GetVectorDotProduct( cross, direction_n ) < 0.0 ){
        degree *= -1.0;
    }

    return degree;
}

stock void MyGetEntityRenderColor(int entity, int aColor[4])
{
	static bool s_GotConfig = false;
	static char s_sProp[32];

	if (!s_GotConfig)
	{
		Handle GameConf = LoadGameConfigFile("core.games");
		bool Exists = GameConfGetKeyValue(GameConf, "m_clrRender", s_sProp, sizeof(s_sProp));
		CloseHandle(GameConf);

		if (!Exists)
			strcopy(s_sProp, sizeof(s_sProp), "m_clrRender");

		s_GotConfig = true;
	}

	int offset = GetEntSendPropOffs(entity, s_sProp);
	if (offset <= 0){
		ThrowError("GetEntityColor not supported by this mod");
	}

	for (int i = 0; i < 4; i++)
		aColor[i] = GetEntData(entity, offset + i, 1) & 0xFF;
}

stock SetEntityColor(int entity, int color[4] = {-1, ...})
{
	int dummy_color[4];
	
	MyGetEntityRenderColor(entity, dummy_color);
	
	for (int i = 0; i <= 3; i++){
		if (color[i] != -1){
			dummy_color[i] = color[i];
		}
	}
	
	SetEntityRenderColor(entity, dummy_color[0], dummy_color[1], dummy_color[2], dummy_color[3]);
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
}

stock bool StringToColor(const char[] str, int color[4], int defvalue = -1)
{
	bool result = false;
	char Splitter[4][64];
	if (ExplodeString(str, " ", Splitter, sizeof(Splitter), sizeof(Splitter[])) == 4 && String_IsNumeric(Splitter[0]) && String_IsNumeric(Splitter[1]) && String_IsNumeric(Splitter[2]) && String_IsNumeric(Splitter[3])){
		color[0] = StringToInt(Splitter[0]);
		color[1] = StringToInt(Splitter[1]);
		color[2] = StringToInt(Splitter[2]);
		color[3] = StringToInt(Splitter[3]);
		result = true;
	}else{
		color[0] = defvalue;
		color[1] = defvalue;
		color[2] = defvalue;
		color[3] = defvalue;
	}
	return result;
}

stock ColorToString(const int color[4], char[] buffer, int size)
{
	Format(buffer, size, "%d %d %d %d", color[0], color[1], color[2], color[3]);
}

stock bool String_IsNumeric(const char[] str)
{
	int x = 0;
	int numbersFound = 0;

	if (str[x] == '+' || str[x] == '-'){
		x++;
	}

	while (str[x] != '\0'){
		if (IsCharNumeric(str[x])){
			numbersFound++;
		}else{
			return false;
		}
		x++;
	}
	if (!numbersFound){
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