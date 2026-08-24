import MyVibeIslandHooks

let output = try HookCLI().run(arguments: Array(CommandLine.arguments.dropFirst()))
if !output.isEmpty {
    print(output, terminator: "")
}
