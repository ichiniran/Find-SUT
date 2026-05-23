import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct TabMenu: View {
    @Binding var isLogin: Bool
    @State private var hasUnreadChat = false
    @State private var hasUnreadNotify = false
    @State private var hideTabBar = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(hideTabBar: $hideTabBar)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            .badge(hasUnreadChat ? "●" : nil)

            PostView()
                .tabItem {
                    Label("Phost", systemImage: "plus")
                }

            NavigationStack {
                NotifyView()
            }
            .tabItem {
                Label("Notify", systemImage: "bell")
            }
            .badge(hasUnreadNotify ? "●" : nil)

            NavigationStack {
                ProfileView(isLogin: $isLogin)
            }
            .tabItem {
                Label("Me", systemImage: "person")
            }
        }
        .onChange(of: hideTabBar) { hide in
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let tabBar = window.rootViewController?.findTabBarController() {
                tabBar.tabBar.isHidden = hide
            }
        }
        .onAppear {
            setupTabBarAppearance()
            listenUnreadChat()
            listenUnreadNotify()
        }
    }

    private func setupTabBarAppearance() {
        let orange = UIColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1)
        let gray   = UIColor(white: 0.67, alpha: 1)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        appearance.stackedLayoutAppearance.selected.iconColor = orange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: orange]
        appearance.stackedLayoutAppearance.selected.badgeBackgroundColor = orange

        appearance.stackedLayoutAppearance.normal.iconColor = gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = orange

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @State private var chatListener: ListenerRegistration?
    @State private var notifyListener: ListenerRegistration?

    func listenUnreadChat() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        chatListener = db.collection("chats")
            .whereField("receiverId", isEqualTo: uid)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snapshot, _ in
                hasUnreadChat = !(snapshot?.isEmpty ?? true)
            }
    }

    func listenUnreadNotify() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        notifyListener = db.collection("users").document(uid)
            .collection("notifications")
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snapshot, _ in
                hasUnreadNotify = !(snapshot?.isEmpty ?? true)
            }
    }
}

// MARK: - UIViewController Helper
extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let tb = self as? UITabBarController { return tb }
        return children.compactMap { $0.findTabBarController() }.first
            ?? presentedViewController?.findTabBarController()
    }
}

#Preview {
    TabMenu(isLogin: .constant(true))
}
