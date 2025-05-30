# Components
## banApi.lua
This component establishes safe custom commands in Cmdr for interfacing with the new Ban API.
It features predefined ban durations corresponding to the current Ohio shadowban scheme (6h/48h/14d) plus permbans.
There's support for two Cmdr roles -- Admin and Hero -- with different ban perms corresponding to the current staff polciy.

Custom commands would be instantiated for either supported role by calling: 
```return require(game.ServerScriptService.Modules.banApi)("Hero")``` 
or
```return require(game.ServerScriptService.Modules.banApi)("Admin")``` 

Example file locations: 
`ServerScriptService/Modules/banApi.lua` 
`ServerScriptService/CmdrCommands/adminBan.lua`
`ServerScriptService/CmdrCommands/heroBan.lua`
