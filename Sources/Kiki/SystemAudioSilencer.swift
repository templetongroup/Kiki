import CoreAudio

/// Temporarily silences the current default output device and restores its
/// exact previous state when recording ends.
final class SystemAudioSilencer {
    private enum StoredValue {
        case uint32(UInt32)
        case float32(Float32)
    }

    private struct Snapshot {
        let deviceID: AudioObjectID
        let address: AudioObjectPropertyAddress
        let value: StoredValue
    }

    private var snapshots: [Snapshot] = []

    var isActive: Bool { !snapshots.isEmpty }

    @discardableResult
    func silence() -> Bool {
        guard snapshots.isEmpty, let deviceID = Self.defaultOutputDevice() else { return false }

        // Prefer the device's mute control. It is lossless and lets macOS show
        // the muted state normally in Control Center and on the keyboard HUD.
        let muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if let previousMute = Self.readUInt32(deviceID, muteAddress),
           Self.isSettable(deviceID, muteAddress),
           Self.writeUInt32(1, to: deviceID, muteAddress) {
            snapshots = [Snapshot(deviceID: deviceID, address: muteAddress, value: .uint32(previousMute))]
            return true
        }

        // Some HDMI, aggregate, and virtual devices expose volume but no mute.
        // Prefer their main control so changing it does not also alter the
        // channel values we are about to snapshot.
        let mainVolumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if let previousVolume = Self.readFloat32(deviceID, mainVolumeAddress),
           Self.isSettable(deviceID, mainVolumeAddress),
           Self.writeFloat32(0, to: deviceID, mainVolumeAddress) {
            snapshots = [Snapshot(deviceID: deviceID, address: mainVolumeAddress, value: .float32(previousVolume))]
            return true
        }

        // Fall back to independent left/right controls only when there is no
        // main volume property.
        for element: AudioObjectPropertyElement in [1, 2] {
            let volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard let previousVolume = Self.readFloat32(deviceID, volumeAddress),
                  Self.isSettable(deviceID, volumeAddress),
                  Self.writeFloat32(0, to: deviceID, volumeAddress) else { continue }
            snapshots.append(Snapshot(deviceID: deviceID, address: volumeAddress, value: .float32(previousVolume)))
        }
        return !snapshots.isEmpty
    }

    func restore() {
        let saved = snapshots
        snapshots.removeAll()
        for snapshot in saved {
            switch snapshot.value {
            case .uint32(let value):
                _ = Self.writeUInt32(value, to: snapshot.deviceID, snapshot.address)
            case .float32(let value):
                _ = Self.writeFloat32(value, to: snapshot.deviceID, snapshot.address)
            }
        }
    }

    deinit {
        restore()
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return deviceID
    }

    private static func isSettable(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(objectID, &address, &settable) == noErr && settable.boolValue
    }

    private static func readUInt32(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> UInt32? {
        var address = address
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func writeUInt32(_ value: UInt32, to objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var value = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(objectID, &address, 0, nil, size, &value) == noErr
    }

    private static func readFloat32(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Float32? {
        var address = address
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func writeFloat32(_ value: Float32, to objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var value = value
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(objectID, &address, 0, nil, size, &value) == noErr
    }
}
