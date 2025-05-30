import { serve } from "https://deno.land/std@0.204.0/http/server.ts";

const banTargets = new Set<string>();

function respond(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "Content-Type": "application/json",
        },
    });
}

serve(async (req) => {
    switch (true) {
        case (req.method == "GET" && req.url == "/ohio/getban"):
            return respond({ targets: Array.from(banTargets) });

        case (req.method == "POST" && req.url == "/ohio/confirmban"):
            return req.json()
                .then((data) => typeof data === "object"
                    && data.username
                    && banTargets.has(data.username)
                    && banTargets.delete(data.username))
                .then(() => respond({ success: true }))
                .catch(() => respond({ success: false }, 500));

        case (req.method == "POST" && req.url == "/ohio/ban"):
            return req.json()
                .then((data) => typeof data === "object"
                    && data.username
                    && banTargets.add(data.username))
                .then(() => respond({ success: true }))
                .catch(() => respond({ success: false }, 500));

        default:
            return respond({ error: "Not Found" }, 404);
    }
});
