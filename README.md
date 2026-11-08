# Unraster Agent Kit

Connect Claude Code, Cursor or Codex to the Unraster MCP server and turn slide images, charts, flowcharts and screenshots into editable PowerPoint (.pptx) or SVG files.

## What it does

- Sends an image (PNG, JPEG or WebP) by https URL or base64 and returns a download link for an editable `.pptx` or `.svg`.
- PowerPoint output keeps text as native text boxes and graphics as separate shapes you can move and recolor. Each image becomes one slide.
- Works for single images through MCP, and for many images through the Batches API (one zip back).
- Real limits: it is not an exact copy of the pixels, fine lettering can stay as shapes, and charts come back as shapes rather than native PowerPoint charts. Check text and details before you use the result.
- Only delivered files are charged. A failed conversion is not charged.

## Quick start

1. Create an API key at https://unraster.ai/developers/api-keys (sign in with Google). The key spends your account credits, so keep it secret.
2. Put it in an environment variable:

   ```bash
   export UNRASTER_API_KEY="your-api-key"
   ```

3. Connect your client. MCP server URL: `https://unraster.ai/mcp` (Streamable HTTP, stateless), authenticated with `Authorization: Bearer $UNRASTER_API_KEY`.

### Claude Code

```bash
claude mcp add --transport http unraster https://unraster.ai/mcp \
  --header "Authorization: Bearer $UNRASTER_API_KEY"
```

Your shell fills in the key when you run the command, and Claude Code saves it in its own configuration. Also see [configs/claude-code.md](configs/claude-code.md).

### Cursor

Add this to `~/.cursor/mcp.json` (or `.cursor/mcp.json` in a project). Cursor reads the key from your environment.

```json
{
  "mcpServers": {
    "unraster": {
      "url": "https://unraster.ai/mcp",
      "headers": {
        "Authorization": "Bearer ${env:UNRASTER_API_KEY}"
      }
    }
  }
}
```

### Codex

Add this to `~/.codex/config.toml`. Codex sends the value of `UNRASTER_API_KEY` as the Bearer token.

```toml
[mcp_servers.unraster]
url = "https://unraster.ai/mcp"
bearer_token_env_var = "UNRASTER_API_KEY"
```

### Other MCP clients

Use the same URL and `Authorization` header in any client that supports Streamable HTTP servers.

### Install the skill (Claude Code or Codex)

The Unraster skill ships as a plugin in [zane-labs/agent-skills](https://github.com/zane-labs/agent-skills). It adds the MCP server for you and tells the agent when to use it, what it costs and where to save the file:

```bash
claude plugin marketplace add zane-labs/agent-skills
claude plugin install unraster@zane-agent-skills
```

For Codex: `codex plugin marketplace add zane-labs/agent-skills`, then `codex plugin add unraster@zane-agent-skills`.

## Tools

| Tool | Access | Inputs | Returns |
| --- | --- | --- | --- |
| `quote_conversion` | Read-only | `outputs`: `pptx`, `svg` or `both` | Credit price and your balance |
| `convert_image` | Spends credits | `image_url` (https) or `image_base64` + `mime_type` (up to 5 MB decoded); `outputs` defaults to `pptx` | Download links and `expires_at`, or a `conversion_id` after about 45 seconds |
| `get_conversion` | Read-only | `conversion_id` | Status, progress and download links when ready |

Example prompts:

- Convert https://example.com/slide.png into an editable PowerPoint and give me the link.
- Check how many credits converting ./chart.png to SVG and PPTX would cost.
- Turn this screenshot into an SVG and save it to assets/logo.svg.

## Pricing

- PowerPoint: 2 credits. Advanced SVG: 1 credit. Both: 3 credits.
- A new API account's first PowerPoint-only conversion (`outputs: pptx`) is free.
- Only delivered files are charged. Quotes, progress checks and downloads are free.
- Subscriptions and credit packs share one credit balance: https://unraster.ai/pricing

## Batch

For many images, use the Batches API: create a batch, upload each file, start it, poll until `finished_at` is set, then download one zip of every delivered file. Batches need a plan with batch access ($49.9/month and up, 50 or 100 files per batch); other plans return `403 plan_required`. Each file can be up to 20 MiB. Credits are reserved for the whole batch when it is created, and only delivered files are charged. The zip is kept for 7 days.

The bundled script does the whole flow with `curl` and `jq`:

```bash
bash scripts/batch.sh pptx results.zip slides/*.png
```

Documentation: https://unraster.ai/docs/api#batches

## Limits

- PNG, JPEG and WebP only.
- Images fetched by URL: up to 25 MiB. Base64 images through MCP: up to 5 MB after decoding.
- Image URLs must use https and point to a public host.
- Download links are valid for 7 days, and anyone with a link can download the file. Do not share them publicly.

## Links

- Website: https://unraster.ai
- Agents and MCP guide: https://unraster.ai/docs/agents
- API documentation: https://unraster.ai/docs/api
- Image to editable PowerPoint: https://unraster.ai/image-to-editable-ppt
- API keys: https://unraster.ai/developers/api-keys
- Privacy: https://unraster.ai/privacy

## License

MIT. See [LICENSE](LICENSE).
