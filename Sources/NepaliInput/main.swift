import InputMethodKit

try runDebugCommandIfRequested()

let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as! String
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier!)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
DictationController.shared.start()
app.run()
