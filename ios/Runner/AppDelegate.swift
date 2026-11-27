import EventKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var remindersChannel: RemindersChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "RemindersChannel") {
      remindersChannel = RemindersChannel(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Bridges `EventKitReminderStore` (Dart) to Apple Reminders via EventKit.
/// Channel: `on_device_agent/reminders`.
final class RemindersChannel {
  private let channel: FlutterMethodChannel
  private let store = EKEventStore()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "on_device_agent/reminders", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "requestAccess": self.requestAccess(result)
      case "create": self.create(args, result)
      case "listOpen": self.listOpen(result)
      case "complete": self.complete(args, result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestAccess(_ result: @escaping FlutterResult) {
    let completion: (Bool, Error?) -> Void = { granted, _ in
      DispatchQueue.main.async { result(granted) }
    }
    if #available(iOS 17.0, *) {
      store.requestFullAccessToReminders(completion: completion)
    } else {
      store.requestAccess(to: .reminder, completion: completion)
    }
  }

  private func create(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let title = args["title"] as? String, !title.isEmpty else {
      result(FlutterError(code: "BAD_ARGS", message: "title is required", details: nil))
      return
    }
    guard let calendar = store.defaultCalendarForNewReminders() else {
      result(FlutterError(code: "NO_LIST", message: "No default Reminders list", details: nil))
      return
    }
    let reminder = EKReminder(eventStore: store)
    reminder.title = title
    reminder.calendar = calendar
    if let millis = args["dueMillis"] as? NSNumber {
      let due = Date(timeIntervalSince1970: millis.doubleValue / 1000)
      reminder.dueDateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: due)
      reminder.addAlarm(EKAlarm(absoluteDate: due))
    }
    do {
      try store.save(reminder, commit: true)
      result(Self.toMap(reminder))
    } catch {
      result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  private func listOpen(_ result: @escaping FlutterResult) {
    let predicate = store.predicateForIncompleteReminders(
      withDueDateStarting: nil, ending: nil, calendars: nil)
    store.fetchReminders(matching: predicate) { reminders in
      let sorted = (reminders ?? []).sorted { a, b in
        switch (Self.dueDate(a), Self.dueDate(b)) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        default: return false
        }
      }
      let maps = sorted.map(Self.toMap)
      DispatchQueue.main.async { result(maps) }
    }
  }

  private func complete(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
      let reminder = store.calendarItem(withIdentifier: id) as? EKReminder
    else {
      result(FlutterError(code: "NOT_FOUND", message: "Reminder not found", details: nil))
      return
    }
    reminder.isCompleted = true
    do {
      try store.save(reminder, commit: true)
      result(nil)
    } catch {
      result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  private static func dueDate(_ reminder: EKReminder) -> Date? {
    guard let components = reminder.dueDateComponents else { return nil }
    return Calendar.current.date(from: components)
  }

  private static func toMap(_ reminder: EKReminder) -> [String: Any] {
    var map: [String: Any] = [
      "id": reminder.calendarItemIdentifier,
      "title": reminder.title ?? "",
      "isCompleted": reminder.isCompleted,
    ]
    if let due = dueDate(reminder) {
      map["dueMillis"] = Int(due.timeIntervalSince1970 * 1000)
    }
    return map
  }
}
