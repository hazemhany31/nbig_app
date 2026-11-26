import Flutter
import UIKit
import FirebaseCore
import MapKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()

    // Register MapKit method channel for native Apple Maps support
    if let controller = window?.rootViewController as? FlutterViewController {
      let mapChannel = FlutterMethodChannel(name: "com.ihealthy.app/maps",
                                            binaryMessenger: controller.binaryMessenger)
      mapChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "openAppleMaps" {
          guard let args = call.arguments as? [String: Any],
                let latitude = args["latitude"] as? Double,
                let longitude = args["longitude"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Latitude and Longitude are required", details: nil))
            return
          }
          let name = args["name"] as? String ?? "Destination"
          
          let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
          let placemark = MKPlacemark(coordinate: coordinate)
          let mapItem = MKMapItem(placemark: placemark)
          mapItem.name = name
          
          let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
          let success = mapItem.openInMaps(launchOptions: launchOptions)
          result(success)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

