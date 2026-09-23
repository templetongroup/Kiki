import Foundation
import Metal

guard CommandLine.arguments.count == 2,
      let device = MTLCreateSystemDefaultDevice() else {
    fatalError("usage: test-metal SHADER_PATH (requires a Metal-capable Mac)")
}
do {
    let source = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    let library = try device.makeLibrary(source: source, options: nil)
    guard !library.functionNames.isEmpty else { fatalError("Shader contains no GPU kernels") }
    print("PASS: packaged Whisper shader compiles on \(device.name); \(library.functionNames.count) kernels")
} catch {
    fputs("FAIL: packaged Whisper GPU source cannot compile: \(error)\n", stderr)
    exit(1)
}
