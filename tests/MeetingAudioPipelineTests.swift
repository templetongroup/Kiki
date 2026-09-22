import Foundation

@main
struct MeetingAudioPipelineTests {
    static func main() async {
        let feed = MeetingPreviewFeed(sampleRate: 10)
        // An hour of numbered samples; a slow consumer must receive recent audio,
        // not an hour-long inference backlog.
        for second in 0..<3600 {
            feed.yield((0..<10).map { Float(second * 10 + $0) })
        }
        feed.finish()
        var windows: [[Float]] = []
        for await window in feed.stream { windows.append(window) }
        precondition(windows.count == 1, "Slow preview must coalesce pending work")
        precondition(windows[0].count == 120, "Preview must stay within 12 seconds")
        precondition(windows[0].first == 35880 && windows[0].last == 35999,
                     "Preview must show the latest continuous audio")
        print("PASS: one-hour preview is bounded and current")
        let short = MeetingPreviewFeed(sampleRate: 10)
        short.yield([1, 2, 3])
        short.finish()
        short.yield([99])
        short.finish()
        var tail: [[Float]] = []
        for await window in short.stream { tail.append(window) }
        precondition(tail == [[1, 2, 3]], "Stop must flush the tail once and reject later audio")
        print("PASS: stop flushes the final preview and closes the feed")
        var audio = Array(repeating: Float(0.2), count: 650)
        for i in 270..<275 { audio[i] = 0 }
        let ranges = MeetingAudioChunks.ranges(audio, sampleRate: 10)
        precondition(ranges.first?.upperBound == 275, "Prefer a pause over cutting at 30 seconds")
        precondition(ranges.flatMap { Array(audio[$0]) } == audio,
                     "Final chunks must retain every sample exactly once")
        precondition(ranges.allSatisfy { $0.count <= 300 }, "Final inference must be bounded")
        print("PASS: pause-aware final chunks preserve all audio exactly once")
        let continuous = Array(repeating: Float(0.5), count: 601)
        precondition(MeetingAudioChunks.ranges(continuous, sampleRate: 10) == [0..<300, 300..<600, 600..<601])
        precondition(MeetingAudioChunks.ranges([], sampleRate: 10).isEmpty)
        print("PASS: continuous speech remains bounded and retains the final sample")
    }
}
