Strange-Lvlr
============
This could be used on just about any server that has random idle players in it.
If a player comes back from being afk then they will have their 'idle' mark removed and teleported back to their spawn.

Existing Features
-----------------
* Detects if some one has been idle for X amount of seconds
* If a player has been idle it will teleport them to a marked location, or to the opposing team's spawn.
* Cvar to set the spawn location for each team manually.
* Customizable idle time, set it to 1.0 if you really want to, just make sure you dont have it kill a player right when they are marked for idle.

Planned Features
----------------
* Kill a player when they become marked as 'idle'
* Color the player to signify that a player is idle
* Remove the ability to move, so players dont go idle then teleport to opposing spawn and start killing
* Cvar methods bit methods: //Making multiple cvars into one.
	* 1 - Disable Moving
	* 2 - Remove Weapons
	* 4 - Kill player when they come back from idle.
	* 8 - Respawn player in their own spawn when they come back.
	* 16 - Kill player right when they are marked for being idle.
* Replenish ammo if you hit an idle player with a bullet. (cvar)
