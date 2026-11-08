# Claude Code

Create a key at https://unraster.ai/developers/api-keys and export it:

```bash
export UNRASTER_API_KEY="your-api-key"
```

Add the MCP server (Streamable HTTP):

```bash
claude mcp add --transport http unraster https://unraster.ai/mcp \
  --header "Authorization: Bearer $UNRASTER_API_KEY"
```

Your shell fills in the key when you run the command, and Claude Code saves it in its own configuration. Run `claude mcp list` to check that `unraster` is connected.

Optional: install the Unraster skill (plugin) from zane-labs/agent-skills.

```bash
claude plugin marketplace add zane-labs/agent-skills
claude plugin install unraster@zane-agent-skills
```
