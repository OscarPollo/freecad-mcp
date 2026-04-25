# Copilot Instructions

## Build, test, and lint commands

- Install Python dependencies for the bridge and FreeCAD-side helpers: `python -m pip install -r config\requirements.txt`
- If `python` is not the active launcher in the current environment, use the equivalent configured launcher such as `python3` for the same commands.
- Build the Docker image used by `.mcp.json` and the README's Copilot CLI flow: `docker build -t freecad-mcp .`
- Verify the repo-scoped Copilot CLI MCP setup from the repository root: `copilot mcp list` and `copilot mcp get freecad`
- Tests in this repo are script-based rather than a single pytest suite. Run them from the repository root:
  - Repo/install smoke test: `python tests\test_installation.py`
  - Modal workflow test against a live FreeCAD session: `python tests\test_modal_workflow.py`
- For a narrower test, run the single script that covers the subsystem you changed instead of treating the whole repo as one suite.
- The installer package in `freecad-mcp-setup\` has its own Node test command: `Set-Location freecad-mcp-setup; npm test`
- There is no dedicated lint command configured in this repository today.

## High-level architecture

- `AICopilot\InitGui.py` is the FreeCAD entry point. When the FreeCAD GUI loads, it auto-starts a global AI service that creates the socket server and event observer. The **AI Copilot** workbench is mainly a management UI; the service is meant to remain available across workbench switches.
- `AICopilot\socket_server.py` is the in-process executor that runs inside FreeCAD. It accepts JSON commands over a local socket, performs GUI/document work on the FreeCAD side, and routes requests through grouped dispatcher APIs such as `partdesign_operations`, `part_operations`, `view_control`, and `execute_python`.
- `working_bridge.py` is the MCP bridge exposed to clients such as Claude Desktop or Copilot CLI. It provides the MCP tool schemas, forwards requests to the FreeCAD socket server, and converts selection-dependent operations into interactive continuation flows with `continue_selection`.
- `AICopilot\event_observer.py` and `AICopilot\memory_system.py` form the learning layer. The observer records selections, document/object changes, and simple interaction signals; the memory system persists sessions, operations, patterns, and preferences in a SQLite database under the user's FreeCAD app-data directory.
- `.mcp.json` is for GitHub Copilot CLI in this repo. It starts the MCP bridge in Docker, but FreeCAD itself still has to be running on the host with the AI Copilot workbench/service active.
- `freecad-mcp-setup\` is a separate Node CLI package that installs the `AICopilot` workbench into FreeCAD's Mod directory, checks for updates, and helps register the MCP bridge. Treat it as a second deliverable with its own test command and release logic.

## MCP server configuration

- This repo already defines a project-scoped `freecad` MCP server in `.mcp.json`. When working in Copilot CLI, start from the repository root so that configuration is discovered automatically.
- The configured `freecad` server runs the bridge through Docker and expects the `freecad-mcp` image to exist locally. Build or rebuild that image before debugging `.mcp.json` issues.
- The MCP bridge is not the FreeCAD process itself. FreeCAD must already be running on the host, with the AI Copilot service active, before MCP calls like `check_freecad_connection` or `part_operations` can succeed.
- On Windows, the README notes that Copilot CLI expects `pwsh.exe` for shell-backed agent actions, so treat missing PowerShell 7 as an environment issue before debugging the MCP config itself.

## Key conventions

- Prefer the grouped dispatcher tools over adding more one-off bridge tools. Both the bridge and the FreeCAD socket server are organized around a small set of broad tool families rather than a large flat tool list.
- Preserve the transport split across platforms: Windows uses TCP (`FREECAD_MCP_HOST`, `FREECAD_MCP_PORT`, and `FREECAD_MCP_BIND_HOST` on the FreeCAD side), while macOS/Linux default to the Unix socket path `/tmp/freecad_mcp.sock`.
- Keep selection-heavy operations in the two-step workflow already used by the bridge/server pair: first request or await selection in FreeCAD, then resume the operation with `continue_selection` after the user has selected edges/faces/objects.
- Keep GUI and document mutations on the FreeCAD side of the boundary. `working_bridge.py` should stay thin; `AICopilot\socket_server.py` is where FreeCAD-specific execution and GUI-safe handlers belong.
- `AICopilot\modal_command_system.py` exists for native FreeCAD dialog workflows, but current socket-server dispatch still handles most operations through the older direct implementations. When updating command flows, verify whether the live path goes through the modal helper or the legacy handler before changing behavior.
- FreeCAD-side persistent data belongs in the user's FreeCAD app-data area, not in the repository. `memory_system.py` already follows that pattern.
