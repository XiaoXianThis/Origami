import AppKit

let app = NSApplication.shared
// 强引用 delegate，避免 NSApplication.delegate 为 weak 时在菜单 action 派发前被释放
private let appDelegate = AppDelegate()

app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()