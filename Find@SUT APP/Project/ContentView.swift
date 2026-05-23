import SwiftUI
import FirebaseAuth

struct ContentView: View {
    
    @State private var isLoading = true
    @State private var isLogin = false
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        ZStack {
            
            if isLoading || (isLogin && userManager.isLoading) {
                // รอทั้ง splash screen และ fetchUser เสร็จ
                OpenApp()
                    .transition(.opacity)
                
            } else if isLogin {
                if userManager.isAdmin {
                    AdminDashboardView()        // ← admin
                } else {
                    TabMenu(isLogin: $isLogin)  // ← user ปกติ
                }
                
            } else {
                LoginView(isLogin: $isLogin)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                }
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    // ใช้ addStateDidChangeListener แทน — จะจับ signOut ได้ด้วย
                    Auth.auth().addStateDidChangeListener { _, user in
                        DispatchQueue.main.async {
                            if user != nil {
                                isLogin = true
                                userManager.fetchUser()
                            } else {
                                isLogin = false
                                userManager.isAdmin = false
                                userManager.username = ""
                                userManager.photoURL = ""
                            }
                            isLoading = false
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BookmarkManager())
        .environmentObject(UserManager())
}
