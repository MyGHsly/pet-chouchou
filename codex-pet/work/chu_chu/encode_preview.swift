import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("usage: encode_preview frames_root output.mp4\n", stderr)
    exit(2)
}
let root = URL(fileURLWithPath: args[1], isDirectory: true)
let output = URL(fileURLWithPath: args[2])
let states = ["idle", "running-right", "running-left", "waving", "jumping", "failed", "waiting", "running", "review"]
var files: [URL] = []
for state in states {
    let dir = root.appendingPathComponent(state, isDirectory: true)
    files += try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}
guard !files.isEmpty else { fatalError("no frames") }
try? FileManager.default.removeItem(at: output)

let width = 384, height = 416
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let attrs: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
writer.add(input)
guard writer.startWriting() else { fatalError("startWriting failed: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

for (index, path) in files.enumerated() {
    guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("bad PNG: \(path.path)") }
    var optionalPixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB,
                                     attrs as CFDictionary, &optionalPixelBuffer)
    guard status == kCVReturnSuccess, let buffer = optionalPixelBuffer else { fatalError("pixel buffer failed") }
    CVPixelBufferLockBaseAddress(buffer, [])
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { fatalError("context failed") }
    context.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 8)) else {
        fatalError("append failed: \(String(describing: writer.error))")
    }
}
input.markAsFinished()
let semaphore = DispatchSemaphore(value: 0)
writer.finishWriting { semaphore.signal() }
semaphore.wait()
guard writer.status == .completed else { fatalError("finish failed: \(String(describing: writer.error))") }
print("wrote \(files.count) frames to \(output.path)")
