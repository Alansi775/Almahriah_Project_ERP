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
      
      if call.method == "showConfirmationAlert" {
        self?.showConfirmationAlert(title: title, message: message, result: result)
      } else if call.method == "showAlert" {
        self?.showNativeAlert(title: title, message: message)
        result(nil)
      } else if call.method == "showToast" {
        self?.showSuccessToast(message: message)
        result(nil)
      } else if call.method == "showActionSheet" {
          let actions = args["actions"] as? [[String: String]] ?? []
          self?.showNativeActionSheet(title: title, actions: actions, result: result)
      } else if call.method == "showEditMessageDialog" { // ✅ New method handler
          self?.showNativeEditMessageDialog(title: "تعديل الرسالة", args: args, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ✅ New method to show a native iOS action sheet
  private func showNativeActionSheet(title: String, actions: [[String: String]], result: @escaping FlutterResult) {
      let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

      for actionData in actions {
          if let actionTitle = actionData["title"], let actionId = actionData["action"] {
              let actionStyle: UIAlertAction.Style = (actionId.contains("delete")) ? .destructive : .default
              let action = UIAlertAction(title: actionTitle, style: actionStyle) { _ in
                  result(actionId)
              }
              alertController.addAction(action)
          }
      }

      alertController.addAction(UIAlertAction(title: "إلغاء", style: .cancel) { _ in
          result(nil)
      })

      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let rootViewController = scene.windows.first?.rootViewController {
          rootViewController.present(alertController, animated: true, completion: nil)
      }
  }

  // ✅ New method to show a native iOS edit message dialog
  private func showNativeEditMessageDialog(title: String, args: [String: Any], result: @escaping FlutterResult) {
      let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
      let initialContent = args["initialContent"] as? String ?? ""

      alertController.addTextField { (textField) in
          textField.text = initialContent
          textField.placeholder = "اكتب رسالتك"
      }

      alertController.addAction(UIAlertAction(title: "حفظ", style: .default, handler: { _ in
          if let newContent = alertController.textFields?.first?.text, !newContent.isEmpty {
              result(newContent)
          } else {
              result(nil)
          }
      }))

      alertController.addAction(UIAlertAction(title: "إلغاء", style: .cancel, handler: { _ in
          result(nil)
      }))

      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let rootViewController = scene.windows.first?.rootViewController {
          rootViewController.present(alertController, animated: true, completion: nil)
      }
  }

  // ✅ Existing method for confirmation alerts
  private func showConfirmationAlert(title: String, message: String, result: @escaping FlutterResult) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
    alertController.addAction(UIAlertAction(title: "حذف", style: .destructive, handler: { _ in
        result(true)
    }))
    
    alertController.addAction(UIAlertAction(title: "إلغاء", style: .cancel, handler: { _ in
        result(false)
    }))
    
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        let rootViewController = scene.windows.first?.rootViewController {
        rootViewController.present(alertController, animated: true, completion: nil)
    }
  }

  // ✅ Existing method to show a native iOS alert
  private func showNativeAlert(title: String, message: String) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "موافق", style: .default, handler: nil))
    
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let rootViewController = scene.windows.first?.rootViewController {
      rootViewController.present(alertController, animated: true, completion: nil)
    }
  }
    
  // ✅ Existing method to show a native iOS toast-like message
  private func showSuccessToast(message: String) {
    if let window = UIApplication.shared.windows.first {
      let toastLabel = UILabel(frame: CGRect(x: 20, y: window.frame.size.height - 100, width: window.frame.size.width - 40, height: 50))
      
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
