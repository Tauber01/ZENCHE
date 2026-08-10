import AppKit
import SwiftUI

enum DesktopWorkspacePreset: String, CaseIterable, Identifiable {
    case standard
    case capture
    case monitor
    case editor
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "默认"
        case .capture: return "拍摄"
        case .monitor: return "监看"
        case .editor: return "编辑"
        case .compact: return "紧凑"
        }
    }

    fileprivate var values: (
        sidebar: CGFloat,
        inspector: CGFloat,
        editorMedia: CGFloat,
        editorTools: CGFloat,
        editorBottom: CGFloat,
        window: NSSize
    ) {
        switch self {
        case .standard:
            return (104, 330, 220, 320, 260, NSSize(width: 1440, height: 900))
        case .capture:
            return (112, 360, 200, 300, 240, NSSize(width: 1500, height: 940))
        case .monitor:
            return (88, 280, 180, 280, 220, NSSize(width: 1540, height: 920))
        case .editor:
            return (96, 300, 250, 360, 280, NSSize(width: 1600, height: 980))
        case .compact:
            return (88, 260, 160, 260, 180, NSSize(width: 1120, height: 720))
        }
    }
}

/// Desktop-only workspace geometry. Values are persisted independently so a
/// user can resize the app and panels directly, then continue from the same
/// arrangement after relaunching.
final class DesktopWorkspaceLayout: ObservableObject {
    static let shared = DesktopWorkspaceLayout()

    private enum Key {
        static let sidebar = "desktop.workspace.sidebar.width.v1"
        static let inspector = "desktop.workspace.inspector.width.v1"
        static let editorMedia = "desktop.workspace.editor.media.width.v1"
        static let editorTools = "desktop.workspace.editor.tools.width.v1"
        static let editorBottom = "desktop.workspace.editor.bottom.height.v1"
    }

    static let sidebarRange: ClosedRange<CGFloat> = 88...220
    static let inspectorRange: ClosedRange<CGFloat> = 260...460
    static let editorMediaRange: ClosedRange<CGFloat> = 160...360
    static let editorToolsRange: ClosedRange<CGFloat> = 260...480
    static let editorBottomRange: ClosedRange<CGFloat> = 160...420

    @Published var sidebarWidth: CGFloat {
        didSet { persist(sidebarWidth, key: Key.sidebar) }
    }
    @Published var inspectorWidth: CGFloat {
        didSet { persist(inspectorWidth, key: Key.inspector) }
    }
    @Published var editorMediaWidth: CGFloat {
        didSet { persist(editorMediaWidth, key: Key.editorMedia) }
    }
    @Published var editorToolsWidth: CGFloat {
        didSet { persist(editorToolsWidth, key: Key.editorTools) }
    }
    @Published var editorBottomHeight: CGFloat {
        didSet { persist(editorBottomHeight, key: Key.editorBottom) }
    }

    private init(defaults: UserDefaults = .standard) {
        sidebarWidth = Self.load(
            defaults: defaults,
            key: Key.sidebar,
            fallback: DesktopWorkspacePreset.standard.values.sidebar,
            range: Self.sidebarRange
        )
        inspectorWidth = Self.load(
            defaults: defaults,
            key: Key.inspector,
            fallback: DesktopWorkspacePreset.standard.values.inspector,
            range: Self.inspectorRange
        )
        editorMediaWidth = Self.load(
            defaults: defaults,
            key: Key.editorMedia,
            fallback: DesktopWorkspacePreset.standard.values.editorMedia,
            range: Self.editorMediaRange
        )
        editorToolsWidth = Self.load(
            defaults: defaults,
            key: Key.editorTools,
            fallback: DesktopWorkspacePreset.standard.values.editorTools,
            range: Self.editorToolsRange
        )
        editorBottomHeight = Self.load(
            defaults: defaults,
            key: Key.editorBottom,
            fallback: DesktopWorkspacePreset.standard.values.editorBottom,
            range: Self.editorBottomRange
        )
    }

    func apply(_ preset: DesktopWorkspacePreset, resizeWindow: Bool = true) {
        let values = preset.values
        sidebarWidth = values.sidebar
        inspectorWidth = values.inspector
        editorMediaWidth = values.editorMedia
        editorToolsWidth = values.editorTools
        editorBottomHeight = values.editorBottom
        guard resizeWindow, let window = NSApp.mainWindow ?? NSApp.keyWindow else {
            return
        }
        DesktopWindowFrame.setVisibleContentSize(values.window, for: window)
    }

    func reset() {
        apply(.standard)
    }

    private func persist(_ value: CGFloat, key: String) {
        UserDefaults.standard.set(Double(value), forKey: key)
    }

    private static func load(
        defaults: UserDefaults,
        key: String,
        fallback: CGFloat,
        range: ClosedRange<CGFloat>
    ) -> CGFloat {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return min(range.upperBound, max(range.lowerBound, defaults.double(forKey: key)))
    }
}

enum DesktopWindowFrame {
    static let autosaveName = "ZENCHE.MainWindow.v1"

    static func restoreOrCenter(_ window: NSWindow) {
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        constrainToVisibleScreen(window)
        window.setFrameAutosaveName(autosaveName)
    }

    static func setVisibleContentSize(_ requested: NSSize, for window: NSWindow) {
        let screen = bestScreen(for: window) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            window.setContentSize(requested)
            return
        }
        let content = NSSize(
            width: min(requested.width, visible.width),
            height: min(requested.height, visible.height)
        )
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
        let origin = NSPoint(
            x: visible.midX - frameSize.width / 2,
            y: visible.midY - frameSize.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: frameSize), display: true, animate: false)
    }

    static func constrainToVisibleScreen(_ window: NSWindow) {
        guard let screen = bestScreen(for: window) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.size.width = min(max(window.minSize.width, frame.width), visible.width)
        frame.size.height = min(max(window.minSize.height, frame.height), visible.height)
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        window.setFrame(frame, display: false)
    }

    private static func bestScreen(for window: NSWindow) -> NSScreen? {
        let frame = window.frame
        return NSScreen.screens.max { first, second in
            first.visibleFrame.intersection(frame).area
                < second.visibleFrame.intersection(frame).area
        }
    }
}

private extension NSRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}

struct WorkspaceSplitHandle: View {
    enum Axis {
        case horizontal
        case vertical
    }

    let axis: Axis
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var reversesHorizontalDirection = false
    @Environment(\.locale) private var locale
    @State private var dragStart: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(
                width: axis == .vertical ? 9 : nil,
                height: axis == .horizontal ? 9 : nil
            )
            .overlay {
                Rectangle()
                    .fill(Palette.rule)
                    .frame(
                        width: axis == .vertical ? 1 : nil,
                        height: axis == .horizontal ? 1 : nil
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if dragStart == nil { dragStart = value }
                        var delta = axis == .vertical
                            ? gesture.translation.width
                            : -gesture.translation.height
                        if axis == .vertical && reversesHorizontalDirection {
                            delta = -delta
                        }
                        let candidate = (dragStart ?? value) + delta
                        value = min(range.upperBound, max(range.lowerBound, candidate))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .focusable()
            .onMoveCommand { direction in
                let step: CGFloat = 8
                switch (axis, direction) {
                case (.vertical, .left) where reversesHorizontalDirection:
                    value = min(range.upperBound, value + step)
                case (.vertical, .right) where reversesHorizontalDirection:
                    value = max(range.lowerBound, value - step)
                case (.vertical, .left), (.horizontal, .down):
                    value = max(range.lowerBound, value - step)
                case (.vertical, .right), (.horizontal, .up):
                    value = min(range.upperBound, value + step)
                default:
                    break
                }
            }
            .accessibilityElement()
            .accessibilityLabel(
                Text(RuntimeLocalization.text(label, locale: locale))
            )
            .accessibilityValue(Text("\(Int(value))"))
            .help(
                Text(
                    RuntimeLocalization.text(
                        "拖动或使用方向键调整",
                        locale: locale
                    )
                )
            )
    }
}
