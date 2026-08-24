import MyVibeIslandApp

let rawArguments = Array(CommandLine.arguments.dropFirst())
var arguments: [String] = []
var index = 0
while index < rawArguments.count {
    if rawArguments[index] == "--state-home" {
        index += min(2, rawArguments.count - index)
    } else {
        arguments.append(rawArguments[index])
        index += 1
    }
}

print(try MyVibeIslandCommandLine(
    application: .production()
).run(arguments: arguments))
