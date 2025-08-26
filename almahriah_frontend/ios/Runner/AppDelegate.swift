import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let dialogChannel = FlutterMethodChannel(name: "com.almahriah.app/dialog", binaryMessenger: controller.binaryMessenger)
    
    dialogChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments not found.", details: nil))
        return
      }
      
      let message = args["message"] as? String ?? "لا توجد رسالة"
      let type = args["type"] as? String
      let title = args["title"] as? String ?? "تنبيه"
      
      // ✅ Handle the new method 'showConfirmationAlert'
      if call.method == "showConfirmationAlert" {
        self?.showConfirmationAlert(title: title, message: message, result: result)
      } else if call.method == "showAlert" {
        self?.showNativeAlert(title: title, message: message)
        result(nil)
      } else if call.method == "showToast" {
        self?.showSuccessToast(message: message)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ✅ New method for confirmation alerts (with "OK" and "Cancel" buttons)
  private func showConfirmationAlert(title: String, message: String, result: @escaping FlutterResult) {
      let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
      
      // "Delete" action returns 'true' to Flutter
      alertController.addAction(UIAlertAction(title: "حذف", style: .destructive, handler: { _ in
          result(true)
      }))
      
      // "Cancel" action returns 'false' to Flutter
      alertController.addAction(UIAlertAction(title: "إلغاء", style: .cancel, handler: { _ in
          result(false)
      }))
      
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = scene.windows.first?.rootViewController {
          rootViewController.present(alertController, animated: true, completion: nil)
      }
  }

  // ✅ Updated function to show a native iOS alert (for errors and confirmations)
  private func showNativeAlert(title: String, message: String) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "موافق", style: .default, handler: nil))
    
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let rootViewController = scene.windows.first?.rootViewController {
      rootViewController.present(alertController, animated: true, completion: nil)
    }
  }
    
  // ✅ New function to show a native iOS toast-like message (for success)
  private func showSuccessToast(message: String) {
    if let window = UIApplication.shared.windows.first {
      let toastLabel = UILabel(frame: CGRect(x: 20, y: window.frame.size.height - 100, width: window.frame.size.width - 40, height: 50))
      
      // ✅ Use dynamic system colors
      toastLabel.backgroundColor = UIColor.systemGray.withAlphaComponent(0.9)
      toastLabel.textColor = UIColor.white
      
      toastLabel.textAlignment = .center
      toastLabel.font = UIFont.systemFont(ofSize: 14)
      toastLabel.text = message
      toastLabel.alpha = 1.0
      toastLabel.layer.cornerRadius = 10
      toastLabel.clipsToBounds = true
      
      window.addSubview(toastLabel)
      
      UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
        toastLabel.alpha = 0.0
      }, completion: {(isCompleted) in
        toastLabel.removeFromSuperview()
      })
    }
  }
}
