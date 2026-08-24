import MyVibeIslandHooks

// The original Hermes plugin launches `vibe-island-bridge --source hermes`
// and streams one hook JSON payload on stdin. Keep that public invocation
// contract while delegating transport to the same local socket client used by
// every other managed hook.
let output = try HookCLI().run(arguments: Array(CommandLine.arguments.dropFirst()))
if !output.isEmpty {
    print(output, terminator: "")
}
