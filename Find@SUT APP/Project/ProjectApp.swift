import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct ProjectApp: App {
    // register app delegate for Firebase setup
     @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var bookmarkManager = BookmarkManager()
    @StateObject var userManager = UserManager()
     var body: some Scene {
       WindowGroup {
         NavigationView {
           ContentView()
                .environmentObject(userManager)
                .environmentObject(bookmarkManager)
                //.environmentObject(BookmarkManager())
                //.environmentObject(UserManager())
         }
         .onAppear {
                bookmarkManager.startListening()
         }
       }
     }
   }
