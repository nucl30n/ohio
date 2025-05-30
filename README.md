### banApi.lua
Ban API module to define custom Cmdr commands and execute bans via an HTTP server (for use with a discord bot or web UI).

### Cmdr Commands
Custom commands are defined by calling `banApigetCmdrDef(role)`:
```lua
return require(game.ServerScriptService.Modules.banApi).getCmdrDef( "`Hero` or `Admin`" )
```

one-liner files could be created for each role in:
- `ServerScriptService/CmdrCommands/adminBan.lua`
- `ServerScriptService/CmdrCommands/heroBan.lua`

### Http Bans
A call to `banApi.polpollHttpServer()` can be added to the `ServerScriptService` to periodically check for bans from the HTTP server.
```lua
require(game.ServerScriptService.Modules.banApi).pollHttpServer()
```

### Http Server
The example http server in `HttpServer.ts` provides a basic implementation for handling ban requests from a Discord bot or web UI.
