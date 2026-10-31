import Foundation
import Metal
import UIKit

// Bridge to the C++ Metal engine, via its narrow C ABI
// (engine/include/spektrafilm/spk_engine.h).
//
// Why this file is small on purpose: the Mac app's EngineClient is an
// actor with logging, progress, caching and a dozen methods. The iPad
// MVP needs only four calls — create, open, set_params, render — plus
// result cleanup. Everything else (Film Edge, batch, MCP, library)
// is out of v1 scope.
//
// Threading: every engine call runs on one serial queue. The session
// pointer is never touched from two threads at once. UI updates are
// published back on the main actor.

struct RenderParams {
    var filmStock: String = "kodak_portra_400"
    var printStock: String = "kodak_supra_endura"
    var exposureEV: Double = 0            // -8 … 8
    var printBrightnessStops: Double = 0  // -3 … 3, converted below
    var yFilterShift: Double = 0          // -1 … 1
    var mFilterShift: Double = 0          // -1 … 1
    var grainActive: Bool = true
    var halationActive: Bool = true
    var glareActive: Bool = true

    func json() throws -> String {
        // Field names are the engine wire names (Mac Params.wire).
        // print_exposure is a factor, not stops: 2^(-stops), clamped.
        let printExposure = min(20, max(0.05, pow(2.0, -printBrightnessStops)))
        let dict: [String: Any] = [
            "film_stock": filmStock,
            "print_stock": printStock,
            "exposure_compensation_ev": exposureEV,
            "auto_exposure": true,
            "film_format_mm": 36.0,
            "grain_active": grainActive,
            "halation_active": halationActive,
            "print_exposure": printExposure,
            "y_filter_shift": yFilterShift,
            "m_filter_shift": mFilterShift,
            "glare_active": glareActive,
            "scan_film": false,
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return String(decoding: data, as: UTF8.self)
    }
}

final class EngineBridge: ObservableObject {
    @Published var statusMessage: String = "未启动"
    @Published var lastError: String?

    private let queue = DispatchQueue(label: "engine", qos: .userInitiated)
    private var engine: OpaquePointer?
    private var session: OpaquePointer?
    private var device: MTLDevice?
    private var currentData: Data?

    enum Failure: Error, LocalizedError {
        case noDevice, engine(String), noSession, render(String), noPixels, noImage
        var errorDescription: String? {
            switch self {
            case .noDevice: return "这台 iPad 没有可用的 Metal 设备"
            case .engine(let m): return "引擎启动失败：\(m)"
            case .noSession: return "请先导入一张照片"
            case .render(let m): return "渲染失败：\(m)"
            case .noPixels: return "渲染没有返回像素"
            case .noImage: return "无法把渲染结果转成图片"
            }
        }
    }

    private func lastEngineError() -> String {
        guard let engine else { return "引擎未启动" }
        return String(cString: spk_last_error(engine))
    }

    private func startIfNeeded() throws {
        if engine != nil { return }
        guard let device = MTLCreateSystemDefaultDevice() else { throw Failure.noDevice }
        self.device = device
        // Resources are copied into the bundle by scripts/setup.sh as
        // a folder named "engine": spektrafilm_constants.bin,
        // profiles/*, print_luts.json, spektrafilm.metallib, etc.
        // If this file is missing, the build script did not run — that is
        // a packaging error, not a render error, so fail loudly here.
        let bundleRoot = Bundle.main.resourceURL!
        let candidates = [
            bundleRoot.appendingPathComponent("engine"),
            bundleRoot.appendingPathComponent("Resources/engine"),
        ]
        guard let resources = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("spektrafilm_constants.bin").path)
        }) else {
            throw Failure.engine("引擎资源缺失（engine/spektrafilm_constants.bin 不在包里），请先跑 scripts/setup.sh 再编译")
        }
        guard let handle = resources.path.withCString({ spk_engine_create($0, Unmanaged.passUnretained(device).toOpaque()) }) else {
            throw Failure.engine(lastEngineError())
        }
        engine = handle
    }

    private func freeReply(_ reply: UnsafeMutablePointer<CChar>?) {
        if let reply { spk_string_free(reply) }
    }

    // MARK: - public API (async, engine work off the main thread)

    func openAndRender(data: Data, params: RenderParams, tier: String) async throws -> UIImage {
        currentData = data
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let image = try self.openAndRenderSync(data: data, params: params, tier: tier)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func reRender(params: RenderParams, tier: String) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let image = try self.reRenderSync(params: params, tier: tier)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - sync engine work, always on `queue`

    private func openAndRenderSync(data: Data, params: RenderParams, tier: String) throws -> UIImage {
        try startIfNeeded()
        guard let engine, let device else { throw Failure.noDevice }
        if let session { spk_session_release(session); self.session = nil }

        let frame = try ImageDecode.frame(from: data, device: device)
        var spkImage = spk_image(
            data: frame.buffer.contents().assumingMemoryBound(to: Float.self),
            width: UInt32(frame.width), height: UInt32(frame.height),
            channels: UInt32(frame.channels))
        var reply: UnsafeMutablePointer<CChar>?
        let delta = try params.json()
        let handle: OpaquePointer? = delta.withCString { deltaPtr in
            withUnsafePointer(to: &spkImage) { spk_open(engine, $0, deltaPtr, &reply) }
        }
        defer { freeReply(reply) }
        guard let handle else { throw Failure.engine(lastEngineError()) }
        session = handle
        return try renderSync(tier: tier)
    }

    private func reRenderSync(params: RenderParams, tier: String) throws -> UIImage {
        guard let session else { throw Failure.noSession }
        var reply: UnsafeMutablePointer<CChar>?
        let delta = try params.json()
        let status = delta.withCString { spk_set_params(session, $0, &reply) }
        freeReply(reply)
        guard status == SPK_OK else { throw Failure.render(lastEngineError()) }
        return try renderSync(tier: tier)
    }

    private func renderSync(tier: String) throws -> UIImage {
        guard let session else { throw Failure.noSession }
        var result = spk_result()
        let status = tier.withCString { spk_render(session, $0, &result) }
        guard status == SPK_OK else { throw Failure.render(lastEngineError()) }
        // Copy pixels first: spk_result_free releases both the texture
        // and the rgba16 memory it points at.
        guard let rgba = result.rgba16 else {
            spk_result_free(&result)
            throw Failure.noPixels
        }
        let width = Int(result.width), height = Int(result.height)
        let bytesPerRow = Int(result.row_stride_px) * 8 // 4 channels x uint16
        let count = bytesPerRow * height
        let copied = Data(bytes: rgba, count: count)
        spk_result_free(&result)

        guard let space = ImageDecode.workingSpace else { throw Failure.noImage }
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
        guard let provider = CGDataProvider(data: copied as CFData),
              let cg = CGImage(width: width, height: height,
                               bitsPerComponent: 16, bitsPerPixel: 64,
                               bytesPerRow: bytesPerRow, space: space,
                               bitmapInfo: bitmapInfo, provider: provider,
                               decode: nil, shouldInterpolate: false,
                               intent: .defaultIntent) else {
            throw Failure.noImage
        }
        return UIImage(cgImage: cg)
    }
}
