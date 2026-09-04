import Foundation
import XeneonWidgetsCore

final class LayoutStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let folder: URL
        if let directory {
            folder = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Application Support", isDirectory: true)
            folder = support.appendingPathComponent("XeneonWidgets", isDirectory: true)
        }
        fileURL = folder.appendingPathComponent("layouts.json", isDirectory: false)
    }

    func load() -> [Preset: LayoutSpec] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        guard let keyed = try? JSONDecoder().decode([String: LayoutSpec].self, from: data) else {
            return [:]
        }
        var result: [Preset: LayoutSpec] = [:]
        for (raw, spec) in keyed {
            if let preset = Preset(rawValue: raw) {
                result[preset] = spec
            }
        }
        return result
    }

    func save(_ layouts: [Preset: LayoutSpec]) {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let keyed = Dictionary(uniqueKeysWithValues: layouts.map { ($0.key.rawValue, $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(keyed) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
