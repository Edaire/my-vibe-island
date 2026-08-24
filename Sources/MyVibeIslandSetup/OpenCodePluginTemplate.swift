public enum OpenCodePluginTemplate {
    public static let contents = """
    // MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN v1
    // Installed by my-vibe-island-setup. Do not edit this managed file directly.

    const hookCommand = process.env.MY_VIBE_ISLAND_HOOKS_COMMAND || "my-vibe-island-hooks"
    const socketPath =
      process.env.MY_VIBE_ISLAND_SOCKET_PATH ||
      process.env.VIBE_ISLAND_SOCKET_PATH ||
      `/tmp/my-vibe-island-${process.getuid()}.sock`

    async function sendToMyVibeIsland(payload) {
      const envelope = {
        schemaVersion: 1,
        clientRole: "hook",
        source: "opencode",
        requestId: payload.id || null,
        command: "hookEvent",
        payload,
      }

      const input = JSON.stringify(envelope)
      const args = ["hook-event", "--socket", socketPath, "--input", input]

      const proc = Bun.spawn([hookCommand, ...args], {
        stdout: "pipe",
        stderr: "pipe",
      })
      const output = await new Response(proc.stdout).text()
      await proc.exited

      const trimmed = output.trim()
      if (!trimmed) {
        return undefined
      }

      return JSON.parse(trimmed)
    }

    export const MyVibeIslandOpenCodePlugin = async () => ({
      "permission.asked": async (input) => {
        return await sendToMyVibeIsland({
          event: "permission",
          id: input.id,
          sessionID: input.sessionID,
          permission: input.permission,
          cwd: input.cwd,
          metadata: input.metadata,
          patterns: input.patterns,
          always: input.always,
        })
      },
      "question.asked": async (input) => {
        return await sendToMyVibeIsland({
          event: "question",
          id: input.id,
          sessionID: input.sessionID,
          cwd: input.cwd,
        })
      },
    })

    """
}
