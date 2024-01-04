import InputMethodKit
import SwiftUI

let connectionName = "GoogleInputTools_Connection"
let bundleId = Bundle.main.bundleIdentifier!

NSLog("creating IMK server")
let server = IMKServer(name: connectionName, bundleIdentifier: bundleId)

NSLog("NSApplication run")
NSApplication.shared.run()
