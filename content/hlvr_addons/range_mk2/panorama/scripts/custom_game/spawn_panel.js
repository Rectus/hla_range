"use strict";

function SpawnItem(itemName)
{
	// Horrible hack. Just send text to VScript to be eval'd as a function call.
	$.DispatchEvent("ClientUI_FireOutputStr", 0, "SpawnItem(\"" + itemName + "\")");
}

function SpawnEnemy(enemyID)
{
	$.DispatchEvent("ClientUI_FireOutputStr", 0, "SpawnEnemy(\"" + enemyID + "\")");
}
