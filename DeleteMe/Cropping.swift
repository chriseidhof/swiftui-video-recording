//

import Foundation
import AVFoundation

struct CropError: Error {
    var message: String
}

extension AVAsset {
    func cropVideo(outputURL: URL, cropRect c: CGRect, pointSize: CGSize) async throws {
        guard let videoTrack = try await loadTracks(withMediaType: .video).first else {
            throw CropError(message: "Invalid video track")
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let scale = naturalSize.width/pointSize.width
        let cropRect = c.applying(.init(scaleX: scale, y: scale))
        let instruction = AVMutableVideoCompositionInstruction()
        let timeRange = try await videoTrack.load(.timeRange)
        instruction.timeRange = timeRange

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = cropRect.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        transformer.setTransform(.init(translationX: -cropRect.minX, y: -cropRect.minY), at: .zero)

        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]

        let saveComposition = AVMutableComposition()
        guard let videoCompositionTrack = saveComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CropError(message: "Can't create video composition track")
        }

        try videoCompositionTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

        guard let exporter = AVAssetExportSession(asset: saveComposition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CropError(message: "Can't create an export session")
        }

        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov

        await exporter.export()

        guard exporter.status == .completed else {
            guard let e = exporter.error else {
                throw CropError(message: "Can't export")
            }
            throw e
        }
    }
}
