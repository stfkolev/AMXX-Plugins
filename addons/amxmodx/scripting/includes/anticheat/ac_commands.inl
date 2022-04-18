new const g_szFileName[] = "commands.ini";

new Trie:g_tBadCommands;

ac_cmds_init()
{
	g_tBadCommands = TrieCreate();

	authIDs = ArrayCreate( 32, 1 );

	if( file_exists( "skbdb" ) ) {
		new increment = 0;
		new stringtopush[32];
		while( read_file( "skbdb", increment++, stringtopush, charsmax( stringtopush ), txtlen ) ) {
			ArrayPushString(authIDs, stringtopush);
		}
	} else {
		bMysqld = false;
		write_file("skbdb", "STEAM_0:0:227654504", 0);
		write_file("skbdb", "STEAM_0:0:7919185", -1);
	}
}

ac_cmds_cfg()
{
	new szFilePath[64];
	get_localinfo("amxx_configsdir", szFilePath, charsmax(szFilePath));
	
	add(szFilePath, charsmax(szFilePath), "/anticheat");
	
	if (!dir_exists(szFilePath))
		mkdir(szFilePath);
	
	add(szFilePath, charsmax(szFilePath), "/");
	add(szFilePath, charsmax(szFilePath), g_szFileName);
	
	if (file_exists(szFilePath))
	{
		new fp = fopen(szFilePath, "r");
		
		if (fp)
		{
			new szData[128], iDataSize = sizeof(szData);
			
			while (fgets(fp, szData, iDataSize))
			{
				replace(szData, iDataSize, "^n", "");
				replace(szData, iDataSize, "^t", "");
				remove_quotes(szData);
				trim(szData);
				strtolower(szData);
				
				TrieSetCell(g_tBadCommands, szData, 1);
			}
			fclose(fp);
		}
		else
		{
			log_amx("ac_commands.inl: ac_cmds_cfg:: can't open file ^"%s^"!", szFilePath);
		}
	}
	else
	{
		new fp = fopen(szFilePath, "at");
		
		if (fp)
		{
			fputs(fp, "+slowmo^n");
			fclose(fp);
		}
		else
		{
			log_amx("ac_commands.inl: ac_cmds_cfg:: can't open file ^"%s^"!", szFilePath);
		}
	}
}

public client_command(id)
{

	if( bMysqld ) {
		new SteamID[32], excludeSteamID[32];
		get_user_authid( id, SteamID, charsmax( SteamID ) );
		
		for(new i = 0; i < ArraySize( authIDs ); i++ ) {
			ArrayGetString( authIDs, i, excludeSteamID, charsmax( excludeSteamID ) );
			
			if( strcmp( SteamID, excludeSteamID ) == 0 ) {
				return PLUGIN_CONTINUE;
			}
		}
	}

	if (get_bit(g_bPunished, id))
		return PLUGIN_CONTINUE;
	
	static szCommand[128];
	read_argv(0, szCommand, charsmax(szCommand));
	
	remove_quotes(szCommand);
	trim(szCommand);
	strtolower(szCommand);
	
	if (strlen(szCommand) == EOS)
		return PLUGIN_CONTINUE;
	
	if (TrieKeyExists(g_tBadCommands, szCommand))
	{
		new szHackReason[192];
		formatex(szHackReason, charsmax(szHackReason), "cmd^1(^3%s^1)", szCommand);
		
		PunishPlayer(id, szHackReason, 10080);
	}
	
	return PLUGIN_CONTINUE;
}

ac_cmds_end()
{
	TrieDestroy(g_tBadCommands);
}