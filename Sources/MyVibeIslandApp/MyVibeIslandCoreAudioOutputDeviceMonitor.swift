import AudioToolbox
import CoreAudio
import Foundation
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandCoreAudioOutputDeviceMonitor {
    private let controller: MyVibeIslandAppKitSoundOutputDeviceObserverController
    private let readSnapshot: () -> SoundOutputDeviceSnapshot?
    private let startListening: (@escaping () -> Void) -> () -> Void
    private var stopListening: (() -> Void)?

    public init(
        controller: MyVibeIslandAppKitSoundOutputDeviceObserverController,
        readSnapshot: @escaping () -> SoundOutputDeviceSnapshot?,
        startListening: @escaping (@escaping () -> Void) -> () -> Void
    ) {
        self.controller = controller
        self.readSnapshot = readSnapshot
        self.startListening = startListening
    }

    public static func production(
        controller: MyVibeIslandAppKitSoundOutputDeviceObserverController = .init()
    ) -> MyVibeIslandCoreAudioOutputDeviceMonitor {
        let source = MyVibeIslandCoreAudioOutputDeviceSource()
        return MyVibeIslandCoreAudioOutputDeviceMonitor(
            controller: controller,
            readSnapshot: source.snapshot,
            startListening: source.start
        )
    }

    public func start() {
        guard stopListening == nil else { return }
        _ = controller.observe(currentSnapshot: readSnapshot())
        stopListening = startListening { [weak self] in
            guard let self else { return }
            _ = self.controller.observe(currentSnapshot: self.readSnapshot())
        }
    }

    public func stop() {
        stopListening?()
        stopListening = nil
    }

}

@MainActor
private final class MyVibeIslandCoreAudioOutputDeviceSource {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private var listener: AudioObjectPropertyListenerBlock?

    func snapshot() -> SoundOutputDeviceSnapshot? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else {
            return nil
        }

        return SoundOutputDeviceSnapshot(
            id: String(device),
            name: deviceName(device) ?? "Audio Output",
            outputVolume: deviceVolume(device) ?? 1,
            observedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    func start(_ handler: @escaping () -> Void) -> () -> Void {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        listener = block
        AudioObjectAddPropertyListenerBlock(systemObject, &address, .main, block)
        return { [weak self] in self?.stop() }
    }

    private func stop() {
        guard let listener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(systemObject, &address, .main, listener)
        self.listener = nil
    }

    private func deviceName(_ device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else {
            return nil
        }
        return name?.takeUnretainedValue() as String?
    }

    private func deviceVolume(_ device: AudioObjectID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else {
            return nil
        }
        return Double(volume)
    }
}
