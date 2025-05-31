    ### `banApi.lua`

    Ban API module to define custom Cmdr commands and execute bans via an HTTP server (for use with a Discord bot or web UI).

    Intended to be added to `ServerScriptService/Modules/`.

    ---

    ### Cmdr Commands

    Custom commands are defined by calling `banApi.getCmdrDef(role)`:

    ```lua
    return require(game.ServerScriptService.Modules.banApi).getCmdrDef(
        -- group: "Hero" or "Admin"
        -- command: "ban", "unban", or "history"
    )
    ```

    Create one-liner files for each role in:
    - `ServerScriptService/CmdrCommands/banAdmin.lua`
    - `ServerScriptService/CmdrCommands/banHero.lua`

    ---

    ### HTTP Bans

    HTTP-based bans can be accomplished by having game servers poll an HTTP server (e.g., `https://devv.games/ohio/api` — placeholder URL).  
    Ensure the actual endpoint is configured properly, and verify if authentication or specific setup is required for accessing the server.

    This allows bans to be managed through a Discord bot or web UI.

    Add a call to `banApi.pollHttpServer()` in `ServerScriptService` to perform this polling:

    ```lua
    require(game.ServerScriptService.Modules.banApi).pollHttpServer()
    ```

    ---

    ### HTTP Server

    An example HTTP server in `HttpServer.ts` would receive periodic requests from game servers and receive bans from a Discord bot or web UI.
