import Foundation
import AVFoundation
import ImageIO
import CoreVideo

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: encode_mp4.swift <png-directory> <output.mp4>")
}

let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let files = try FileManager.default.contentsOfDirectory(at: inputDirectory, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else { fatalError("no PNG frames") }

try? FileManager.default.removeItem(at: output)
let width = 384
let height = 448
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let attributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
guard writer.canAdd(input) else { fatalError("cannot add video input") }
writer.add(input)
guard writer.startWriting() else { fatalError("startWriting: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

for (index, file) in files.enumerated() {
    while !input.isReadyForMoreMediaData { usleep(10_000) }
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let pool = adaptor.pixelBufferPool else {
        fatalError("cannot read frame \(file.path)")
    }
    var pixelBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
          let buffer = pixelBuffer else {
        fatalError("cannot allocate pixel buffer")
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    guard let data = CVPixelBufferGetBaseAddress(buffer),
          let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
          ) else {
        fatalError("cannot create frame context")
    }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    let time = CMTime(value: Int64(index * 9), timescale: 60)
    guard adaptor.append(buffer, withPresentationTime: time) else {
        fatalError("append frame \(index): \(String(describing: writer.error))")
    }
}

input.markAsFinished()
let semaphore = DispatchSemaphore(value: 0)
writer.finishWriting { semaphore.signal() }
semaphore.wait()
guard writer.status == .completed else { fatalError("finishWriting: \(String(describing: writer.error))") }
print("wrote \(output.path)")
