import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// One-photo MVP UI, iPad-first: large preview on the left/top,
// film/paper + a few sliders in a side panel. No library, no batch,
// no Film Edge in v1. Sliders re-render the "preview" tier; Export
// renders the "full" tier and opens the system share sheet.

struct ContentView: View {
    @EnvironmentObject private var engine: EngineBridge

    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceData: Data?
    @State private var preview: UIImage?
    @State private var exported: UIImage?
    @State private var isWorking = false
    @State private var message: String = "先从相册或文件导入一张照片。"
    @State private var showFileImporter = false

    @State private var filmID = "kodak_portra_400"
    @State private var paperID = "kodak_supra_endura"
    @State private var exposureEV = 0.0
    @State private var brightnessStops = 0.0
    @State private var yShift = 0.0
    @State private var mShift = 0.0
    @State private var grain = true
    @State private var halation = true

    private var params: RenderParams {
        RenderParams(filmStock: filmID, printStock: paperID,
                     exposureEV: exposureEV, printBrightnessStops: brightnessStops,
                     yFilterShift: yShift, mFilterShift: mShift,
                     grainActive: grain, halationActive: halation)
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: import + stocks + parameters.
            Form {
                Section("导入") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("从相册选择", systemImage: "photo")
                    }
                    Button { showFileImporter = true } label: {
                        Label("从文件选择", systemImage: "folder")
                    }
                    Text("v1 先支持 JPEG / HEIF / PNG / TIFF；RAW 仍在验证中，失败请先转 16 位 TIFF。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("胶片") {
                    Picker("胶片", selection: $filmID) {
                        ForEach(Stocks.films) { Text($0.name).tag($0.id) }
                    }
                    .onChange(of: filmID) { _, newValue in
                        // Follow the Mac app's pairing: a film change
                        // moves the paper to its paired paper, if any.
                        if let target = Stocks.film(newValue)?.targetPrint {
                            paperID = target
                        }
                        rerender()
                    }
                }
                Section("相纸") {
                    Picker("相纸", selection: $paperID) {
                        ForEach(Stocks.papers) { Text($0.name).tag($0.id) }
                    }
                    .onChange(of: paperID) { _, _ in rerender() }
                }
                Section("参数") {
                    SliderRow(title: "曝光补偿", value: $exposureEV, range: -3...3, format: "%.2f EV", onChange: rerender)
                    SliderRow(title: "印相亮度", value: $brightnessStops, range: -3...3, format: "%.2f 档", onChange: rerender)
                    SliderRow(title: "黄滤色", value: $yShift, range: -1...1, format: "%.2f", onChange: rerender)
                    SliderRow(title: "品红滤色", value: $mShift, range: -1...1, format: "%.2f", onChange: rerender)
                    Toggle("颗粒", isOn: $grain).onChange(of: grain) { _, _ in rerender() }
                    Toggle("光晕", isOn: $halation).onChange(of: halation) { _, _ in rerender() }
                }
                Section("导出") {
                    Button("全分辨率导出并分享") { exportFull() }
                        .disabled(sourceData == nil || isWorking)
                    Text("导出用 full 档渲染，分享为 JPEG；PNG/TIFF 导出是下一步，不是 v1。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("SpektraLab iPad")
        } detail: {
            ZStack {
                if let preview {
                    Image(uiImage: preview)
                        .resizable().scaledToFit().background(Color.black)
                } else {
                    ContentUnavailableView("还没有照片", systemImage: "photo",
                                           description: Text(message))
                }
                if isWorking {
                    ProgressView("正在冲印…").padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar {
                if let exported {
                    ShareLink(item: Image(uiImage: exported), preview: SharePreview("SpektraLab 导出", image: Image(uiImage: exported)))
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await open(data: data)
                } else {
                    message = "无法读取这张照片，请改用“从文件选择”。"
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    Task { await open(data: data) }
                }
            case .failure(let error):
                message = "读取文件失败：\(error.localizedDescription)"
            }
        }
    }

    private func open(data: Data) async {
        sourceData = data
        isWorking = true
        defer { isWorking = false }
        do {
            preview = try await engine.openAndRender(data: data, params: params, tier: "preview")
            message = "已冲印（预览档）。"
        } catch {
            message = "失败：\(error.localizedDescription)"
        }
    }

    private func rerender() {
        guard sourceData != nil else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                preview = try await engine.reRender(params: params, tier: "preview")
            } catch {
                message = "重印失败：\(error.localizedDescription)"
            }
        }
    }

    private func exportFull() {
        guard sourceData != nil else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                exported = try await engine.reRender(params: params, tier: "full")
                message = "全分辨率导出完成，点右上角分享。"
            } catch {
                message = "导出失败：\(error.localizedDescription)"
            }
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value)).foregroundStyle(.secondary)
            }
            // Render once when the drag ends, not on every tick:
            // the engine queue is serial and a tick-by-tick flood would
            // backlog behind the slider.
            Slider(value: $value, in: range) { editing in
                if !editing { onChange() }
            }
        }
    }
}
