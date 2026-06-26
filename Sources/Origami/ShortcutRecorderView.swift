import Carbon
import SwiftUI

enum ShortcutDisplay {
    static func string(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += keyCodeToString(keyCode)
        return result
    }

    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            break
        }

        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var maxChars = 4
        var chars = [UniChar](repeating: 0, count: maxChars)
        let status = UCKeyTranslate(
            keyLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            maxChars,
            &maxChars,
            &chars
        )
        if status == noErr, maxChars > 0 {
            return String(utf16CodeUnits: chars, count: maxChars).uppercased()
        }
        return "Key \(keyCode)"
    }
}

@MainActor
private final class LocalKeyEventMonitor {
    private var monitor: Any?

    func start(_ handler: @escaping (NSEvent) -> NSEvent?) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

@MainActor
struct ShortcutRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    @State private var isRecording = false
    @State private var keyMonitor = LocalKeyEventMonitor()

    private var shortcut: TabSwitchShortcut {
        TabSwitchShortcut(
            keyCode: UInt16(clamping: keyCode),
            modifiers: UInt(bitPattern: modifiers)
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("切换标签快捷键")
            Spacer()
            Button(action: toggleRecording) {
                Text(isRecording ? "按下快捷键…" : shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 96)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isRecording ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("恢复默认") {
                stopRecording()
                let defaultShortcut = TabSwitchShortcut.default
                keyCode = Int(defaultShortcut.keyCode)
                modifiers = Int(bitPattern: defaultShortcut.modifiers)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        keyMonitor.start { event in
            if event.keyCode == 53 {
                Task { @MainActor in
                    stopRecording()
                }
                return event
            }

            let relevantModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            let capturedModifiers = event.modifierFlags.intersection(relevantModifiers)
            guard !capturedModifiers.isEmpty else { return nil }

            keyCode = Int(event.keyCode)
            modifiers = Int(bitPattern: capturedModifiers.rawValue)
            Task { @MainActor in
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        keyMonitor.stop()
    }
}
