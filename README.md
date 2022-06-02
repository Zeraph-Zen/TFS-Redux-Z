# Team Fortress Sandbox Redux Zen
Place prop_dynamic_overrides, edit their appearance and properties, and build cool stuff!
This is an further updated and improved version Bolt's version of KTM's TFS plugin.

The SMLib version used for this plugin was made by Adrianilloo, and can be found here https://github.com/Adrianilloo/smlib/tree/transitional_syntax

## Features (so far):
```
- Spawn in props! Edit the prop list by editing proplist.cfg. Old plugin had hardcoded prop lists.
- Move and rotate props around via the Manipulate menu!
- Edit various properties of props, such as rotation, color, collision, transparency, saturation, and size with the Edit menu!
- Delete a single prop you are looking at, or clear all of your props at once!
- Cvar that sets everyone's personal prop limit!: sm_tfs_proplimit (def. 50)
- TFS Admin Menu
- Player collision check after prop manipulation. This stops propblocking.
- Build zones! Players can only build and manipulate props while in these zones!
- Ability to check who owns the prop you're looking at.
```

## Commands and ConVars
```
- sm_tfs: Opens up the main menu
- sm_tfs_admin: Quickly brings up the Admin menu (also shown in sm_tfs if have access to this cmd)
- sm_tfs_proplimit (def. 50): Proplimit for each user
```

## CREDITS:
- KTM: He developed the original TFS Plugin that was used for the {SuN} and {SuN} Revived servers.
- Bolt: Created the TFS Redux plugin this is based on.
- Batfoxkid#7401: Fixed up the plugin a bit and created a functional build zone system.

## To do:
```
- Add more props to proplist.cfg (event props, weapon mdls, hat mdls, etc)
- Personal player settings (manipulate beam color, POSSIBLE different entity types such as prop_physics, etc)
- Improved build zone functions (Disable placing things outside of buildzones)
- Another config file for setting things such as sounds, manipulation beam textures, etc
- More cvars, such as one to toggle the plugin, and to toggle build zones.
- A command to clear all of a specific users props.
```
