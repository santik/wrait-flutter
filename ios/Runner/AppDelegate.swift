import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let deviceIdChannelName = "wrait/preferences"
  private let entryExportChannelName = "wrait/entry_export"
  private let getDeviceIdMethod = "getDeviceId"
  private let writeCsvExportMethod = "writeCsvExport"

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

    let exportChannel = FlutterMethodChannel(
      name: entryExportChannelName,
      binaryMessenger: registrar.messenger()
    )
    exportChannel.setMethodCallHandler { [weak self] (
      call: FlutterMethodCall,
      result: @escaping FlutterResult
    ) in
      guard let self else {
        result(
          FlutterError(
            code: "entry_export_failed",
            message: "AppDelegate was deallocated before handling the export request",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case self.writeCsvExportMethod:
        guard
          let arguments = call.arguments as? [String: Any],
          let fileName = (arguments["fileName"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
          ),
          !fileName.isEmpty,
          let contents = arguments["contents"] as? String,
          !contents.isEmpty
        else {
          result(
            FlutterError(
              code: "entry_export_failed",
              message: "Invalid export arguments.",
              details: nil
            )
          )
          return
        }

        do {
          let pathLabel = try self.writeCsvExport(fileName: fileName, contents: contents)
          result(["fileName": fileName, "pathLabel": pathLabel])
        } catch {
          result(
            FlutterError(
              code: "entry_export_failed",
              message: "Failed to write CSV export.",
              details: error.localizedDescription
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func writeCsvExport(fileName: String, contents: String) throws -> String {
    let exportDirectory = try exportDirectoryUrl()
    let exportFile = exportDirectory.appendingPathComponent(fileName)
    try contents.write(to: exportFile, atomically: true, encoding: .utf8)
    return "Files/Wrait Exports"
  }

  private func exportDirectoryUrl() throws -> URL {
    guard
      let documentsDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
      ).first
    else {
      throw CocoaError(.fileNoSuchFile)
    }

    let exportDirectory = documentsDirectory.appendingPathComponent(
      "Wrait Exports",
      isDirectory: true
    )
    var isDirectory = ObjCBool(false)
    if FileManager.default.fileExists(atPath: exportDirectory.path, isDirectory: &isDirectory) {
      if !isDirectory.boolValue {
        throw NSError(
          domain: "WraitEntryExport",
          code: 1,
          userInfo: [
            NSLocalizedDescriptionKey: "The export directory path is occupied by a file."
          ]
        )
      }
      return exportDirectory
    }

    try FileManager.default.createDirectory(
      at: exportDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return exportDirectory
  }
}
