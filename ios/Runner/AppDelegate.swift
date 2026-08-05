import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}



// import Flutter
// import UIKit

// @main
// @objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     #if DEBUG
//     var args = ProcessInfo.processInfo.arguments
//     args.append("-FIRDebugEnabled")
//     args.append("-FIRAnalyticsDebugEnabled")
//     ProcessInfo.processInfo.setValue(args, forKey: "arguments")
//     #endif

//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }

//   func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
//     GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
//   }
// }


// import Flutter
// import UIKit

// @main
// @objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     #if DEBUG
//     // Force native Firebase Analytics DebugView mode for development builds
//     UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
//     UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
//     UserDefaults.standard.synchronize()
//     #endif
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }

//   func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
//     GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
//   }
// }