import CoreGraphics
import CoreImage
import Metal
import UIKit

// Decode to the engine's input format, following the Mac app's
// ImageDecoder.engineFrame: tightly packed float32 RGBA, linear
// ProPhoto, top row first, in a shared MTLBuffer.
//
// Two load-bearing details copied from the Mac code, with reasons:
//  - render with `toBitmap` into the buffer's own memory (not
//    `render(_:to:)` into a texture, which needs a vertical flip and
//    is not bit-identical here);
//  - no vertical flip: `toBitmap` already writes top row first.
//
// v1 limitation, stated plainly: this path is for flat files
// (JPEG/HEIF/PNG/TIFF). RAW is best-effort — CIImage may decode some
// DNGs, but the Mac app's dedicated CIRAWFilter route (lens correction,
// as-shot white balance, linear vs display looks) is NOT ported yet.
// If a RAW file fails here, convert it to 16-bit TIFF first and retry.

enum ImageDecode {
    // Linear ProPhoto (ROMM, gamma 1.0), constructed from published
    // ROMM primaries against D50 — Core Graphics ships ROMM at gamma
    // 1.8 and linear sRGB/P3, but no linear ROMM.
    static let linearProPhoto: CGColorSpace? = {
        let d50: [CGFloat] = [0.9642, 1.0000, 0.8249]
        let black: [CGFloat] = [0, 0, 0]
        let gamma: [CGFloat] = [1, 1, 1]
        let primaries: [CGFloat] = [
            0.7976749, 0.2880402, 0.0000000,
            0.1351917, 0.7118741, 0.0000000,
            0.0313534, 0.0000857, 0.8252100,
        ]
        return d50.withUnsafeBufferPointer { wp in
            black.withUnsafeBufferPointer { bp in
                gamma.withUnsafeBufferPointer { gp in
                    primaries.withUnsafeBufferPointer { mp in
                        CGColorSpace(calibratedRGBWhitePoint: wp.baseAddress!,
                                     blackPoint: bp.baseAddress!,
                                     gamma: gp.baseAddress!,
                                     matrix: mp.baseAddress)
                    }
                }
            }
        }
    }()

    // Working space for display/export: ROMM RGB, gamma 1.8, D50.
    static let workingSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.rommrgb)

    static let context: CIContext = {
        let device = MTLCreateSystemDefaultDevice()!
        return CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!,
            .workingFormat: CIFormat.RGBAh,
            .cacheIntermediates: false,
        ])
    }()

    struct Frame {
        let buffer: MTLBuffer
        let width: Int
        let height: Int
        let channels: Int // always 4 here; the engine drops alpha on the GPU
    }

    enum Failure: Error, LocalizedError {
        case noImage, noColorSpace, emptyFrame, noBuffer
        var errorDescription: String? {
            switch self {
            case .noImage: return "无法解码这张图片（v1 先用 JPEG/HEIF/PNG/TIFF，RAW 仍在验证中）"
            case .noColorSpace: return "无法构造线性 ProPhoto 色彩空间"
            case .emptyFrame: return "解码出的画面没有像素"
            case .noBuffer: return "无法为解码画面分配内存（大图请先缩小或分批处理）"
            }
        }
    }

    static func frame(from data: Data, device: MTLDevice) throws -> Frame {
        guard let ci = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw Failure.noImage
        }
        return try frame(from: ci, device: device)
    }

    static func frame(from image: CIImage, device: MTLDevice) throws -> Frame {
        guard let space = linearProPhoto else { throw Failure.noColorSpace }
        guard !image.extent.isInfinite, !image.extent.isEmpty else { throw Failure.emptyFrame }
        let extent = image.extent.integral
        let width = Int(extent.width), height = Int(extent.height)
        let placed = image.transformed(by: .init(translationX: -extent.origin.x, y: -extent.origin.y))
        guard let buffer = device.makeBuffer(length: width * height * 16, options: .storageModeShared) else {
            throw Failure.noBuffer
        }
        autoreleasepool {
            context.render(placed, toBitmap: buffer.contents(), rowBytes: width * 16,
                           bounds: CGRect(x: 0, y: 0, width: width, height: height),
                           format: .RGBAf, colorSpace: space)
        }
        return Frame(buffer: buffer, width: width, height: height, channels: 4)
    }
}
