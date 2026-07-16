@preconcurrency import Carbon
import Foundation

@MainActor
final class HotKeyMonitor {
    static let shared = HotKeyMonitor()
    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?

    func register(choice: HotKeyChoice = .optionSpace) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if hotKeyID.id == 1 {
                Task { @MainActor in HotKeyMonitor.shared.onPress?() }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        let id = EventHotKeyID(signature: OSType(0x50535458), id: 1) // PSTX
        let key: UInt32 = choice == .optionSpace ? UInt32(kVK_Space) : UInt32(kVK_ANSI_V)
        let modifiers: UInt32 = choice == .optionSpace ? UInt32(optionKey) : UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(key, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

}
