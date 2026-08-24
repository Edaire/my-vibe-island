import Foundation
import MyVibeIslandSetup

let result = SetupCLIExitRunner().run(arguments: Array(CommandLine.arguments.dropFirst()))
if !result.stdout.isEmpty { print(result.stdout) }
if !result.stderr.isEmpty { fputs("\(result.stderr)\n", stderr) }
exit(result.exitCode)
