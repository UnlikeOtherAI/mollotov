# Mollotov — Feature Catalogue

Every user-facing feature is described here. When adding or changing a feature, update this file in the same commit.

## Floating Menu

The floating action button (bottom-right) provides quick access to browser tools. Current items: Reload, Safari Login, Settings.

### Bookmarks

Saved URLs accessible from the floating menu. Bookmarks are fully controllable through the MCP and CLI — an LLM or user can add, remove, and list bookmarks remotely. Tapping a bookmark navigates the browser to that URL. Primary use case: quick access to project URLs pushed from the CLI without manual typing.

### History

Chronological log of every URL navigated to in the browser. Viewable from the floating menu, clearable by the user or via API. Enables quick return to previously visited pages.

### Network Inspector

A Charles Proxy-style network traffic viewer built into the app. Captures all HTTP/HTTPS requests and responses flowing through the loaded website.

**List view:**
- Every request displayed with its HTTP method (GET, POST, PUT, DELETE, OPTIONS, etc.), URL, status code, and content type.
- Filterable by: HTTP method, content type (JSON, HTML, CSS, JS, images, fonts, etc.), status code range, URL pattern.
- Sortable by time, duration, size.

**Detail view (drill-down):**
- Request: method, URL, headers, query parameters, body (formatted for JSON payloads).
- Response: status code, headers, body (formatted for JSON, syntax-highlighted where possible).
- Timing: start time, duration, size transferred.

**LLM integration:**
- The LLM can navigate the user to a specific request by index or URL pattern.
- When the user is viewing a specific request, the LLM has full context of that request's details and can debug it — inspecting headers, payloads, and response data on behalf of the user.
- MCP tools and CLI commands for listing, filtering, and inspecting captured requests.
