import Foundation
import Darwin

/// Boundary for V3's `FocusModeLogStream`. The process source is deliberately
/// kept separate from the quiet-scene reducer: it only forwards complete
/// `log stream` lines and owns original-process restart behaviour.
@MainActor
final class MyVibeIslandAppKitFocusModeLogStream {
    static let executableURL = URL(fileURLWithPath: "/usr/bin/log")
    static let arguments = [
        "stream",
        "--no-backtrace",
        "--style", "compact",
        "--level", "info",
        "--predicate",
        "process == \"duetexpertd\" AND eventMessage CONTAINS \"semanticModeIdentifier\"",
    ]

    private let onLine: @MainActor (String) -> Void
    private var process: Process?
    private var outputPipe: Pipe?
    private var restartWorkItem: DispatchWorkItem?
    private var restartBackoff: TimeInterval = 1
    private var receivedOutput = false
    private var stopped = false
    private var buffer: FocusModeLogLineBuffer

    init(onLine: @escaping @MainActor (String) -> Void) {
        self.onLine = onLine
        self.buffer = FocusModeLogLineBuffer()
    }

    func start() {
        guard stopped == false, process == nil else { return }
        launch()
    }

    func stop() {
        stopped = true
        restartWorkItem?.cancel()
        restartWorkItem = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        let childProcess = process
        childProcess?.terminationHandler = nil
        if let childProcess, childProcess.isRunning {
            childProcess.terminate()
            // `log stream` can outlive its parent pipe after SIGTERM. The
            // monitor owns this short-lived helper, so do not leave an
            // orphaned stream behind when teardown is requested.
            if childProcess.isRunning {
                kill(childProcess.processIdentifier, SIGKILL)
            }
        }
        process = nil
        outputPipe = nil
        buffer = FocusModeLogLineBuffer()
    }

    private func launch() {
        guard stopped == false, process == nil else { return }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = Self.executableURL
        process.arguments = Self.arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        receivedOutput = false
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor [weak self] in
                self?.receive(data)
            }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.processDidTerminate()
            }
        }

        do {
            try process.run()
            self.process = process
            outputPipe = pipe
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            scheduleRestart()
        }
    }

    private func receive(_ data: Data) {
        guard data.isEmpty == false else { return }
        if receivedOutput == false {
            receivedOutput = true
            restartBackoff = 1
        }
        buffer.append(data, onLine: onLine)
    }

    private func processDidTerminate() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        scheduleRestart()
    }

    private func scheduleRestart() {
        guard stopped == false, restartWorkItem == nil else { return }
        let delay = restartBackoff
        restartBackoff = min(restartBackoff * 2, 30)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.restartWorkItem = nil
            self.launch()
        }
        restartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

struct FocusModeLogLineBuffer {
    private var pending = Data()
    private var onLine: ((String) -> Void)?

    init(onLine: ((String) -> Void)? = nil) {
        self.onLine = onLine
    }

    mutating func append(_ data: Data, onLine: ((String) -> Void)? = nil) {
        if let onLine {
            self.onLine = onLine
        }
        pending.append(data)
        while let newline = pending.firstIndex(of: 0x0A) {
            let lineData = pending.prefix(upTo: newline)
            pending.removeSubrange(...newline)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            self.onLine?(line)
        }
    }
}
