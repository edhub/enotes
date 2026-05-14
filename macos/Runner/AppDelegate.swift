import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// 尽早注册 Apple Event handler（kInternetEventClass / kAEGetURL）。
  /// 部分浏览器通过 Launch Services 派发 URL 时走此路径，
  /// 意味着 app_links 插件自己的 handler 因时序问题永远注册不上。
  override func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleURLEvent(_:withReply:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  @objc private func handleURLEvent(
    _ event: NSAppleEventDescriptor,
    withReply reply: NSAppleEventDescriptor
  ) {
    guard
      let urlString = event
        .paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
        .stringValue
    else { return }
    NSLog("[eNotes] Apple Event URL: %@", urlString)
    AppLinks.shared.handleLink(link: urlString)
  }

  /// NSWorkspace.open 派发的 URL 走此路径。
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      NSLog("[eNotes] application(_:open:) URL: %@", url.absoluteString)
      AppLinks.shared.handleLink(link: url.absoluteString)
    }
  }
}
