import { serve } from "https://deno.land/std@0.204.0/http/server.ts";

const banTargets = new Set<string>();

function respond(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

serve(async (req) => {
    const url = new URL(req.url, "http://x");
    switch (true) {
        case (req.method === "GET" && url.pathname === "/ohio/getban"):
            return respond({ targets: Array.from(banTargets) });

        case (req.method === "POST" && url.pathname === "/ohio/confirmban"):
            return req.json()
                .then((data) => {
                    if (typeof data === "object" && data.userId && banTargets.has(data.userId)) {
                        banTargets.delete(data.userId);
                        return respond({ success: true });
                    }
                    return respond({ success: false }, 400);
                })
                .catch(() => respond({ success: false }, 500));

        case (req.method === "POST" && url.pathname === "/ohio/ban"):
            return req.json()
                .then((data) => {
                    if (typeof data === "object" && data.userId) {
                        banTargets.add(data.userId);
                        return respond({ success: true });
                    }
                    return respond({ success: false }, 400);
                })
                .catch(() => respond({ success: false }, 500));

        default:
            return respond({ error: "Not Found" }, 404);
    }
});
