//

import SwiftUI
import ReplayKit


struct ContentView: View {
    @State private var detail = false
    @Namespace private var ns

    @State var toggle = false

    var body: some View {
        VStack {
            subject
            RecordButton(outputURL: URL(filePath: "/Users/chris/Downloads/my-video.mp4")) {
                try await Task.sleep(for: .milliseconds(500))
                detail.toggle()
                try await Task.sleep(for: .milliseconds(1000))
                detail.toggle()
                try await Task.sleep(for: .milliseconds(500))
            }
        }
        .recordingWindow()
    }
    var subject: some View {
        ZStack {
            if detail {
                Color.red
                    .matchedGeometryEffect(id: "rect", in: ns)
                    .frame(width: 100, height: 100)
            } else {
                Color.red
                    .matchedGeometryEffect(id: "rect", in: ns)
                    .frame(width: 300, height: 300)
            }
        }
        .animation(.default, value: detail)
        .frame(width: 300, height: 300)
        .padding(10)
        .recordingSubject()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            detail.toggle()
        }
    }
}
