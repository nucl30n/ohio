### banApi.lua
Ban API module to define custom Cmdr commands and execute bans via an HTTP server (for use with a discord bot or web UI).

Intended to be added to `ServerScriptService/Modules/`.

### Cmdr Commands
Custom commands are defined by calling `banApi.getCmdrDef(role)`:
```lua
return require(game.ServerScriptService.Modules.banApi).getCmdrDef(`group:` "Hero" or "Admin" )
```

one-liner files for each role in:
- `ServerScriptService/CmdrCommands/banAdmin.lua`
- `ServerScriptService/CmdrCommands/banHero.lua`

### Http Bans
Http-based bans can be accomplished by having game servers polling an http server (something like `https://devv.games/ohio/api`) at a regular interval and running the bans that are returned.
This allows for bans to be managed through a Discord bot or a web UI.

A call to `banApi.pollHttpServer()` can be added to the `ServerScriptService`  to perform this polling.
```lua
require(game.ServerScriptService.Modules.banApi).pollHttpServer()
```

### Http Server
example http server in `HttpServer.ts` would recieve periodic requests from game servers and recieve bans from a Discord bot or web UI.
