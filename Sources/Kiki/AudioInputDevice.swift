import AVFoundation
import AudioToolbox
import CoreAudio

struct AudioInputDeviceDescriptor: Equatable {
    let name: String
    let uniqueID: String
}

enum AudioInputDevice {
    static func available() -> [AudioInputDeviceDescriptor] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
            .map { AudioInputDeviceDescriptor(name: $0.localizedName, uniqueID: $0.uniqueID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func selected(from devices: [AudioInputDeviceDescriptor], preferredID: String?) -> AudioInputDeviceDescriptor? {
        if let preferredID, let preferred = devices.first(where: { $0.uniqueID == preferredID }) {
            return preferred
        }
        return devices.first
    }

    static func apply(uniqueID: String, to audioUnit: AudioUnit) throws {
        guard let deviceID = coreAudioDeviceID(for: uniqueID) else {
            throw KikiError("The selected microphone is no longer available.")
        }
        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw KikiError("Kiki could not use the selected microphone (\(status)).")
        }
    }

    private static func coreAudioDeviceID(for uniqueID: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount
        ) == noErr else { return nil }

        let count = Int(byteCount) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount,
            &devices
        ) == noErr else { return nil }

        for device in devices {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString?
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            let status = withUnsafeMutablePointer(to: &uid) { pointer in
                AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, pointer)
            }
            if status == noErr, let uid, uid as String == uniqueID { return device }
        }
        return nil
    }
}
