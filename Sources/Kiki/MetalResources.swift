import Foundation

/// ggml compiles its Metal shaders at runtime (we build without Xcode's
/// build-time Metal compiler). It finds the shader source via the
/// GGML_METAL_PATH_RESOURCES environment variable, so point that at
/// whichever directory actually contains ggml-metal.metal.
enum MetalResources {
    static func configure() {
        let env = ProcessInfo.processInfo.environment
        if env["GGML_METAL_PATH_RESOURCES"] != nil { return }

        let fm = FileManager.default
        var candidates: [URL] = []

        if let res = Bundle.main.resourceURL {
            candidates.append(res)
            candidates.append(contentsOf: bundleSubdirectories(of: res))
        }
        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(exeDir)
            candidates.append(contentsOf: bundleSubdirectories(of: exeDir))
        }

        for dir in candidates {
            if fm.fileExists(atPath: dir.appendingPathComponent("ggml-metal.metal").path) {
                setenv("GGML_METAL_PATH_RESOURCES", dir.path, 1)
                return
            }
        }
        // No shader source found: ggml logs a warning and whisper falls back to CPU.
    }

    private static func bundleSubdirectories(of dir: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        return entries.filter { $0.pathExtension == "bundle" }
    }
}
