import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("usage: extract_video_frames video.mp4 output_dir\n", stderr)
    exit(2)
}
let source = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let asset = AVURLAsset(url: source)
let duration = CMTimeGetSeconds(asset.duration)
print("duration=\(duration)")
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
for index in 0..<7 {
    let seconds = max(0, duration * Double(index + 1) / 8.0)
    let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
    let destination = out.appendingPathComponent(String(format: "%02d.png", index))
    guard let writer = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("could not write png") }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { fatalError("could not finish png") }
    print("\(index): \(String(format: "%.2f", seconds))s \(image.width)x\(image.height)")
}
