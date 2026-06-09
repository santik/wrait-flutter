import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let deviceIdChannelName = "wrait/preferences"
  private let getDeviceIdMethod = "getDeviceId"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "WraitDeviceIdBridge"
    ) else {
      return
    }

    let channel = FlutterMethodChannel(
      name: deviceIdChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (
      call: FlutterMethodCall,
      result: @escaping FlutterResult
    ) in
      guard let self else {
        result(
          FlutterError(
            code: "device_id_unavailable",
            message: "AppDelegate was deallocated before handling the device ID request",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case self.getDeviceIdMethod:
        if let identifier = UIDevice.current.identifierForVendor?.uuidString,
          !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
          result(identifier)
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
