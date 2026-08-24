import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHTunnelProcessController {
    public private(set) var processes: [SSHTunnelProcess]
    public private(set) var lastPublishedProcesses: [SSHTunnelProcess]?

    private let publishProcesses: @MainActor ([SSHTunnelProcess]) -> Void

    public init(
        processes: [SSHTunnelProcess] = [],
        publishProcesses: @escaping @MainActor ([SSHTunnelProcess]) -> Void = { _ in }
    ) {
        self.processes = Self.sorted(processes)
        self.publishProcesses = publishProcesses
    }

    @discardableResult
    public func upsert(_ process: SSHTunnelProcess) -> [SSHTunnelProcess] {
        var next = processes.filter {
            $0.hostId != process.hostId || $0.generation != process.generation
        }
        next.append(process)
        processes = Self.sorted(next)
        publishCurrentProcesses()
        return processes
    }

    @discardableResult
    public func remove(hostId: String, generation: Int) -> Bool {
        let next = processes.filter {
            $0.hostId != hostId || $0.generation != generation
        }
        guard next.count != processes.count else {
            return false
        }

        processes = next
        publishCurrentProcesses()
        return true
    }

    private func publishCurrentProcesses() {
        lastPublishedProcesses = processes
        publishProcesses(processes)
    }

    private static func sorted(_ processes: [SSHTunnelProcess]) -> [SSHTunnelProcess] {
        processes.sorted {
            if $0.hostId == $1.hostId {
                return $0.generation < $1.generation
            }
            return $0.hostId < $1.hostId
        }
    }
}
