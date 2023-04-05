//

import Foundation
import SwiftUI
import ReplayKit

extension View {
    public func recordingSubject() -> some View {
        anchorPreference(key: SubjectFrame.self, value: .bounds, transform: { $0 })
    }

    public func recordingWindow() -> some View {
        modifier(RecordingWindow())
    }
}

struct RecordingWindow: ViewModifier {
    @State private var viewInfo: ViewInfo?

    func body(content: Content) -> some View {
        content
            .environment(\.viewInfo, viewInfo)
            .overlayPreferenceValue(SubjectFrame.self) { frame in
            GeometryReader { proxy in
                if let frame {
                    let viewInfo = ViewInfo(windowSize: proxy.size, viewFrame: proxy[frame])
                    Color.clear
                        .onAppear {
                            self.viewInfo = viewInfo
                        }.onChange(of: viewInfo) {
                            self.viewInfo = $0
                        }
                }
            }
        }
    }
}

struct SubjectFrame: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value ?? nextValue()
    }
}

struct ViewInfo: Equatable {
    var windowSize: CGSize
    var viewFrame: CGRect
}

struct ViewInfoKey: EnvironmentKey {
    static var defaultValue: ViewInfo? = nil
}

extension EnvironmentValues {
    var viewInfo: ViewInfo? {
        get { self[ViewInfoKey.self] }
        set { self[ViewInfoKey.self] = newValue }
    }
}

public struct RecordButton: View {
    @Environment(\.viewInfo) private var viewInfo
    @StateObject private var model = Model()
    var outputURL: URL
    var actions: () async throws -> ()

    public init(outputURL: URL, actions: @escaping () async throws -> Void) {
        self.outputURL = outputURL
        self.actions = actions
    }

    public var body: some View {
        Button("Record") {
            Task {
                if let v = viewInfo {
                    do {
                        try await model.start()
                        try await actions()
                        try await model.stop(v, output: outputURL)
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .disabled(viewInfo == nil)
    }
}


@MainActor
final class Model: ObservableObject {
    let recorder = RPScreenRecorder.shared()
    @Published var recording: Bool = false

    init() { }

    @Published var output: URL?

    func start() async throws {
        recorder.isMicrophoneEnabled = false
        recorder.isCameraEnabled = false
        guard recorder.isAvailable else {
            throw CropError(message: "Recorder not available")
        }
        try await withUnsafeThrowingContinuation { (cont: UnsafeContinuation<(), Error>) in
            recorder.startRecording { err in
                if let err {
                    cont.resume(throwing: err)
                } else {
                    DispatchQueue.main.async {
                        self.recording = true
                        cont.resume()
                    }
                }
            }
        }
    }

    func stop(_ viewInfo: ViewInfo, output: URL) async throws {
        recording = false
        let url = URL.temporaryDirectory.appendingPathComponent("out.mp4")
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        try? fm.removeItem(at: output)
        try await recorder.stopRecording(withOutput: url)
        try await AVAsset(url: url).cropVideo(outputURL: output, cropRect: viewInfo.viewFrame.offsetBy(dx: 0, dy: 28), pointSize: viewInfo.windowSize)
        try fm.removeItem(at: url)
    }
}
