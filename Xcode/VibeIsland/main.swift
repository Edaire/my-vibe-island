import MyVibeIslandApp

print(try MyVibeIslandCommandLine(
    application: .production()
).run(arguments: ["--app", "--run-appkit"]))
