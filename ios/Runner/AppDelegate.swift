import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let authCallbackChannelName = "xviewer/auth_callback"
  private let authCallbackEventsName = "xviewer/auth_callback/events"
  private var pendingCallbackUrl: String?
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(
        name: authCallbackChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      methodChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "consumePendingCallbackUrl" else {
          result(FlutterMethodNotImplemented)
          return
        }

        result(self?.pendingCallbackUrl)
        self?.pendingCallbackUrl = nil
      }

      let eventChannel = FlutterEventChannel(
        name: authCallbackEventsName,
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(AuthCallbackStreamHandler(appDelegate: self))
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if handleCallback(url: url) {
      return true
    }

    return super.application(app, open: url, options: options)
  }

  fileprivate func attachEventSink(_ sink: FlutterEventSink?) {
    eventSink = sink
    if let sink, let pendingCallbackUrl {
      sink(pendingCallbackUrl)
      self.pendingCallbackUrl = nil
    }
  }

  fileprivate func handleCallback(url: URL) -> Bool {
    guard
      url.scheme == "xviewer",
      url.host == "auth",
      url.path == "/callback"
    else {
      return false
    }

    let callbackUrl = url.absoluteString
    if let eventSink {
      eventSink(callbackUrl)
    } else {
      pendingCallbackUrl = callbackUrl
    }
    return true
  }
}

final class AuthCallbackStreamHandler: NSObject, FlutterStreamHandler {
  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  private weak var appDelegate: AppDelegate?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.attachEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    appDelegate?.attachEventSink(nil)
    return nil
  }
}
