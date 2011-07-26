##mcbot.sh##
###A minecraft server bot for vanilla servers.###

This script is intended to work with a vanilla server running in a screen session.  If you do not know what that is or how to set it up, I recommend you learn how or turn away.

Currently, this bot provides the following commands/services:

*  Message Of The Day.

*  Notifies users of online players on login.

*  Provides /list for non-ops.

*  Provides /help to show available commands.

*  Provieds /tp to allow player-to-player teleportation.

*  Provides /seen to query the last logged in time of a user.

Soon to be reimplemented features:

*  Provides /get for nether items on servers that do not have the nether enabled.  Has daily allowances.

Todo:

*  Will provide a /mail system to leave short messages for users.

Installation:

Copy the mcbot.sh and the mcbot folder to your server's folder or wherever you'd like to run the bot from.  Be sure to edit the variables in the top of mcbot.sh to suit your setup.  Start the bot however you'd like, be it via cron, some startup script, manually, or otherwise.  Really, you should know what to do with this before setting it up.

I'll be transitioning my server from the [server startup script](http://www.minecraftwiki.net/wiki/Server_startup_script) on the wiki to [Dagmar's Sysv init script](http://www.minecraftforum.net/topic/186525-sysv-init-script-v106-for-linux/), so expect this script to eventually suit that better.