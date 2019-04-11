# [Cs:S] SM: Hide and Seek
Source mod Hide and Seek for Counter Strike : Source


What's this?
--------------------------------
Terrorists "Hiders" choose a random model on spawn, like a chair, plant or a sign, which is common on the played map and search a place, where they blend in best. The CTs "Seekers" wait a specified time to give the hiders a chance to find their spot. They have to search for the hiders and shoot them.

Seekers either lose some health (default 5 hp) on every shot or hiders get more invisible everytime they get shot - or both. Seekers gain hp by hurting or killing a hider.

Requirements
--------------------------------

   [SourceMod latest stable release](https://www.sourcemod.net/)
    
Download Link
--------------------------------
    
   Stable : [Version 1.5.1.1](https://github.com/blackdevil72/-Cs-S-SM-Hide-and-Seek/releases/download/1.5.1.1/css_hns_1.5.1.1.zip)
   
   Dev Build : [Version 1.6.0 Dev](https://github.com/blackdevil72/-Cs-S-SM-Hide-and-Seek/releases/download/1.6.0_dev_1/css_hide_and_seek_1.6.0.dev4.zip) (please read release note for more information)

Player Commands
--------------------------------

    /hide /hidemenu - Opens the menu with the list of available models if still enabled
    /tp /third /thirdperson /+3rd /-3rd - Switches to the thirdperson view so hiders see how they fit into the environment
    /whistle - Hiders play a random sound to give the seekers a hint
    /freeze - Toggles freezing for hiders
    /whoami - Shows hiders their current model name again
    /hidehelp - Displays a panel with informations how to play.


Plugin Cvars
--------------------------------

    sm_hns_version - Gives plugins version
    sm_hns_enable - Enable the Hide and Seek mod? (Default: 1)
    sm_hns_freezects - Should CTs get freezed and blinded on spawn? (Default: 1)
    sm_hns_freezetime - How long should the CTs are freezed after spawn? (Default: 25.0)
    sm_hns_changelimit - How often a T is allowed to choose his model ingame? (Default: 2)
    sm_hns_changelimittime - How long should a T be allowed to change his model again after spawn? (Default: 30.0)
    sm_hns_autochoose - Should the plugin choose models for the hiders automatically? (Default: 0)
    sm_hns_whistle - Are terrorists allowed to whistle? (Default: 1)
    sm_hns_whistle_times - How many times a hider is allowed to whistle per round? (Default: 5)
    sm_hns_hider_win_frags - How many frags should surviving hiders gain? (Default: 5)
    sm_hns_hp_seeker_enable - Should CT lose HP when shooting, 0 = off/1 = on. (Default 1)
    sm_hns_hp_seeker_dec - How many HP should a CT lose on shooting? (Default 5)
    sm_hns_hp_seeker_inc - How many hp should a CT gain when hitting a hider? (Default 15)
    sm_hns_hp_seeker_bonus - How many hp should a CT gain when killing a hider? (Default 50)
    sm_hns_opacity_enable - Should T get more invisible on low hp, 0 = off/1 = on. (Default 0)
    sm_hns_hidersspeed - Hiders speed (Default: 1.00)
    sm_hns_disable_rightknife - Disable rightclick for CTs with knife? Prevents knifing without losing heatlh. (Default: 1)
    sm_hns_disable_ducking - Disable ducking. (Default: 0)
    sm_hns_auto_thirdperson - Enable thirdperson view for hiders automatically (Default: 1)
    sm_hns_slay_seekers - Slay seekers on round end, if there are still hiders alive? (Default: 0)
    sm_hns_hider_freeze_mode - What to do with the /freeze command? (Default: 2)
        0: Disables /freeze command for hiders
        1: Only freeze on position, be able to move camera
        2: Freeze completely (no cameramovents)
    sm_hns_hide_blood - Hide blood on hider damage. (Default: 1)
    sm_hns_show_hidehelp - Show helpmenu explaining the game on first player spawn. (Default: 1)
    sm_hns_ct_ratio - The ratio of hiders to 1 seeker. 0 to disables teambalance. (Default: 3:1)
    sm_hns_show_progressbar - Show progressbar for last 15 seconds of freezetime. (Default: 1)
    sm_hns_disable_use - Disable CTs pushing things. (Default: 1)
    sm_hns_hider_freeze_inair - Are hiders allowed to freeze in the air? (Default: 0)
    sm_hns_anticheat - Check player cheat convars, 0 = off/1 = on. (Default: 0)
    sm_hns_whistle_delay - How long after spawn should we delay the use of whistle? (Default: 25.0)
    sm_hns_cheat_punishment - How to punish players with wrong cvar values after 15 seconds? (Default: 1)
        0: Disabled
        1: Switch to Spectator
        2: Kick
    sm_hns_remove_shadows - Remove shadows from players and physic models? (Default: 1)
    sm_hns_use_taxed_in_random - Include taxed models when using random model choice? (Default: 0)


Protected Server Cvars
--------------------------------
There are some protected server convars, which are enforced by the plugin to enable the mod to operate properly:

    mp_flashlight 0
    sv_footsteps 0
    mp_limitteams 0
    mp_autoteambalance 0
    mp_freezetime 0
    sv_nonemesis 1
    sv_nomvp 1
    sv_nostats 1
    mp_playerid 1
    sv_allowminmodels 0
    mp_teams_unbalance_limit 0
    sv_turbophysics 1

It's recommend to set mp_forcecamera to 1 in your server.cfg!


Admin commands
--------------------------------

    sm_hns_force_whistle <#userid|steamid|name> - Force a player to whistle disregarding his whistle limit. (chat flag)
    sm_hns_reload_models - Reload the modellist from the map config file. (rcon flag)


Adding new maps
--------------------------------
By default the plugin currently comes with a choice of models for all default maps for CS:S, but it's really easy to add support for any other map. You should only use maps with lot's of props, so hiders aren't that obvious to find.

Just create a new textfile in the /configs/hide_and_seek/maps folder named the same as the map you want to support. Check the existing files for the format - you're allowed to add as many models and languages as you want. Make sure to set the file encoding to UTF-8 without BOM (more info).
I'd always appreciate it if you would share your model configs so they get added to the package by default.

There are some special keys to set:

    "heightfix" "[addheight]" (e.g. "heightfix" "80")
        Some models are bugged and halfway in the ground. You're able to add this key to get them showing up over the ground when standing still. Hiders using a bugged model will be teleported up regularly while running, so they can't hide by constantly running against a wall staying in the ground.
    "tax" "[money]" (e.g. "tax" "600")
        You're able to put taxes on some models to prevent everyone from using it every round. Useful for small models.
        Since Hiders don't get that much money during gameplay, don't set the tax too high. (If you've got some ideas for events to give hiders money for, let me know!)

Don't hesitate to send me your map configuration!

Original Source Code
--------------------------------

   [http://code.google.com/p/smhideandseek/](http://code.google.com/p/smhideandseek/)
