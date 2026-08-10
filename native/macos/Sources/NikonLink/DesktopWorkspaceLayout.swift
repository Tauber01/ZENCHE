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
            return (112, 380, 240, 380, 360, NSSize(width: 1480, height: 940))
        case .capture:
            return (120, 420, 220, 360, 320, NSSize(width: 1540, height: 960))
        case .monitor:
            return (96, 320, 200, 340, 300, NSSize(width: 1580, height: 940))
        case .editor:
            return (104, 360, 280, 440, 480, NSSize(width: 1680, height: 1020))
        case .compact:
            return (88, 260, 160, 280, 240, NSSize(width: 1160, height: 760))
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
        // v2 gives the vertically dense AI workspace a useful first-run height
        // without rewriting the user's other saved panel widths.
        static let editorBottom = "desktop.workspace.editor.bottom.height.v2"
    }

    static let splitHandleThickness: CGFloat = 12
    static let minimumCaptureCanvasWidth: CGFloat = 560
    static let minimumEditorCanvasWidth: CGFloat = 360
    static let minimumEditorPreviewHeight: CGFloat = 240

    static let sidebarRange: ClosedRange<CGFloat> = 72...360
    static let inspectorRange: ClosedRange<CGFloat> = 240...720
    static let editorMediaRange: ClosedRange<CGFloat> = 140...520
    static let editorToolsRange: ClosedRange<CGFloat> = 280...720
    static let editorBottomRange: ClosedRange<CGFloat> = 220...720

    static let minimumCaptureWorkspaceWidth = minimumCaptureCanvasWidth
        + inspectorRange.lowerBound
        + splitHandleThickness
    static let minimumEditorWorkspaceWidth = minimumEditorCanvasWidth
        + editorMediaRange.lowerBound
        + editorToolsRange.lowerBound
        + splitHandleThickness * 2
    static let minimumWorkspaceWidth = max(
        minimumCaptureWorkspaceWidth,
        minimumEditorWorkspaceWidth
    )

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

    static func sidebarRange(
        forAvailableWidth availableWidth: CGFloat
    ) -> ClosedRange<CGFloat> {
        constrainedRange(
            sidebarRange,
            maximum: availableWidth - minimumWorkspaceWidth
                - splitHandleThickness
        )
    }

    static func inspectorRange(
        forAvailableWidth availableWidth: CGFloat
    ) -> ClosedRange<CGFloat> {
        constrainedRange(
            inspectorRange,
            maximum: availableWidth - minimumCaptureCanvasWidth
                - splitHandleThickness
        )
    }

    static func editorToolsRange(
        forAvailableWidth availableWidth: CGFloat
    ) -> ClosedRange<CGFloat> {
        constrainedRange(
            editorToolsRange,
            maximum: availableWidth - minimumEditorCanvasWidth
                - editorMediaRange.lowerBound
                - splitHandleThickness * 2
        )
    }

    static func editorMediaRange(
        forAvailableWidth availableWidth: CGFloat,
        toolsWidth: CGFloat
    ) -> ClosedRange<CGFloat> {
        constrainedRange(
            editorMediaRange,
            maximum: availableWidth - minimumEditorCanvasWidth
                - toolsWidth
                - splitHandleThickness * 2
        )
    }

    static func editorBottomRange(
        forAvailableHeight availableHeight: CGFloat
    ) -> ClosedRange<CGFloat> {
        constrainedRange(
            editorBottomRange,
            maximum: availableHeight - minimumEditorPreviewHeight
                - splitHandleThickness
        )
    }

    static func clamp(
        _ value: CGFloat,
        to range: ClosedRange<CGFloat>
    ) -> CGFloat {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private static func constrainedRange(
        _ preferred: ClosedRange<CGFloat>,
        maximum: CGFloat
    ) -> ClosedRange<CGFloat> {
        preferred.lowerBound...max(
            preferred.lowerBound,
            min(preferred.upperBound, maximum)
        )
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
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(
                width: axis == .vertical
                    ? DesktopWorkspaceLayout.splitHandleThickness
                    : nil,
                height: axis == .horizontal
                    ? DesktopWorkspaceLayout.splitHandleThickness
                    : nil
            )
            .overlay {
                Rectangle()
                    .fill(
                        isHovered || isDragging
                            ? Palette.editorAccent
                            : Palette.rule
                    )
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
                        isDragging = true
                        var delta = axis == .vertical
                            ? gesture.translation.width
                            : -gesture.translation.height
                        if axis == .vertical && reversesHorizontalDirection {
                            delta = -delta
                        }
                        let candidate = (dragStart ?? value) + delta
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            value = min(
                                range.upperBound,
                                max(range.lowerBound, candidate)
                            )
                        }
                    }
                    .onEnded { _ in
                        dragStart = nil
                        isDragging = false
                    }
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    (axis == .vertical
                        ? NSCursor.resizeLeftRight
                        : NSCursor.resizeUpDown).set()
                } else {
                    NSCursor.arrow.set()
                }
            }
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
