# MCP directory listing fields

Use these values when submitting the Unraster remote MCP server to any MCP directory. Only the remote Streamable HTTP form exists; there is nothing to install or run locally.

| Field | Value |
| --- | --- |
| Name | Unraster |
| Short name / slug | unraster |
| One-line description | Convert images, slides and screenshots into editable PowerPoint (.pptx) or SVG files. |
| Website | https://unraster.ai |
| Documentation | https://unraster.ai/docs/agents |
| Source / config examples | https://github.com/zane-labs/unraster-mcp |
| Operator | Zane |
| License of this repository | MIT |
| Category | Productivity, Design, File conversion |

## Long description

Unraster turns an image of a slide, chart, flowchart, table, infographic or screenshot into an editable PowerPoint (.pptx) or an SVG. Text comes back as native PowerPoint text boxes and graphics come back as separate shapes. An agent sends a PNG, JPEG or WebP image by https URL or base64, quotes the credit price first, then converts and receives download links valid for 7 days. Only delivered files are charged; a failed conversion is not charged. It is not an exact copy of the pixels: some fine lettering can stay as shapes, and charts come back as shapes rather than native charts.

## Connection

| Field | Value |
| --- | --- |
| Transport | Streamable HTTP (stateless, JSON responses) |
| Server URL | https://unraster.ai/mcp |
| Authentication | API key as a Bearer token: `Authorization: Bearer <API key>` |
| Where to get a key | https://unraster.ai/developers/api-keys (sign in with Google) |
| Key permissions | `conversions:read` (quote, status) and `conversions:write` (convert) |
| OAuth | Not supported; API key only |
| Cost | Credits: SVG 1, PowerPoint 2, both 3. A new API account's first PowerPoint-only conversion is free. Pricing: https://unraster.ai/pricing |

If a directory requires a client-side header example:

```
Authorization: Bearer ${UNRASTER_API_KEY}
```

## Tools

| Tool | Read-only | Description | Inputs |
| --- | --- | --- | --- |
| `quote_conversion` | yes | Show the credit price of converting an image to editable PowerPoint and/or SVG, and the account balance. Free. | `outputs` (`pptx`, `svg`, `both`; default `pptx`); optional `image_url`, `image_base64`, `mime_type` |
| `convert_image` | no | Convert a PNG, JPEG or WebP image into an editable PowerPoint and/or SVG and return download links. Charged only for delivered files. Waits about 45 seconds, then returns a `conversion_id`. | `image_url` (https, up to 25 MiB) or `image_base64` + `mime_type` (up to 5 MB decoded); `outputs` |
| `get_conversion` | yes | Check the status, progress and download links of a conversion. Free. | `conversion_id` (required) |

## Notes for reviewers

- Test access: a reviewer needs their own API key; a new API account's first PowerPoint-only conversion is free.
- Privacy policy: https://unraster.ai/privacy
- Download links are public to anyone holding the link and expire after 7 days.

## Registry formats

- The official MCP registry `server.json` needs a verified namespace (for example a GitHub-based `io.github.<owner>/...` name) that the publisher has to choose and prove ownership of, so it is not included here. When that namespace exists, use a `remotes` entry of type `streamable-http` with URL `https://unraster.ai/mcp` and an `Authorization` header marked secret.
- Directories that read a repository (README, tools list) can use this repository as is.
