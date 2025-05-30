# Components
## banApi.lua
This component establishes safe custom commands in Cmdr for interfacing with the new Ban API.
It features predefined ban durations corresponding to the current Ohio shadowban scheme (6h/48h/14d) plus permbans.

## adminBan.lua & heroBan.lua
There's support for two Cmdr roles -- Admin and Hero -- with different ban perms corresponding to the staff polciy.

Custom commands are  instantiated by calling: 
> return require(game.ServerScriptService.Modules.banApi)("`Hero` or `Admin` ")



Example file locations: 
`ServerScriptService/Modules/banApi.lua` 
`ServerScriptService/CmdrCommands/adminBan.lua`
`ServerScriptService/CmdrCommands/heroBan.lua`
