import SwiftUI
import FirebaseFirestore
import FirebaseAuth
struct AdminDashboardView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var totalFound: Int = 0
    @State private var totalLost: Int = 0
    @State private var totalUsers: Int = 0
    @State private var pendingReports: Int = 0
    @State private var isLoading = true
    @State private var showLogoutAlert = false
    @State private var unreadMessages: Int = 0
    @State private var unreadListener: ListenerRegistration?
    var totalPosts: Int { totalFound + totalLost }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // HEADER
                ZStack {
                    Color.formBackground.ignoresSafeArea(edges: .top)
                    HStack {
                        Spacer()
                        Text("Admin Dashboard")
                            .font(.headline)
                            .foregroundColor(Color.darkText)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 50)

                Divider()

                if isLoading {
                    Spacer()
                    ProgressView().tint(.orange)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {

                            // MARK: - โพสต์ทั้งหมด
                            statCard(
                                title: "โพสต์ทั้งหมด",
                                value: "\(totalPosts)",
                                icon: "doc.text.fill",
                                color: Color.orange,
                                subtitle: "พบของ \(totalFound)  |  ของหาย \(totalLost)"
                            )

                            // MARK: - ผู้ใช้งาน
                            statCard(
                                title: "ผู้ใช้งานทั้งหมด",
                                value: "\(totalUsers)",
                                icon: "person.2.fill",
                                color: Color(hex: "#3B82F6"),
                                subtitle: "จำนวนบัญชีในระบบ"
                            )

                            // MARK: - รายงานที่ยังไม่ตรวจสอบ
                            statCard(
                                title: "รายงานที่รอตรวจสอบ",
                                value: "\(pendingReports)",
                                icon: "flag.fill",
                                color: Color(hex: "#EF4444"),
                                subtitle: "สถานะ: รอตรวจ"
                            )

                            // MARK: - เมนู
                            VStack(spacing: 0) {
                                menuRow(
                                    icon: "doc.text",
                                    title: "จัดการโพสต์",
                                    color: .orange,
                                    destination: AnyView(AdminPostsView())
                                )
                                Divider().padding(.leading, 56)
                                menuRow(
                                    icon: "person.2",
                                    title: "จัดการผู้ใช้",
                                    color: Color(hex: "#3B82F6"),
                                    destination: AnyView(AdminUsersView())
                                )
                                Divider().padding(.leading, 56)
                                menuRow(
                                    icon: "flag",
                                    title: "จัดการรายงาน",
                                    color: Color(hex: "#EF4444"),
                                    destination: AnyView(AdminReportsView()),
                                    badge: pendingReports
                                )
                                Divider().padding(.leading, 56)
                                    menuRow(
                                        icon: "bubble.left.and.bubble.right",
                                        title: "กล่องข้อความ",
                                        color: Color.orange,
                                        destination: AnyView(AdminChatInboxView()),
                                        badge: unreadMessages
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                            Button {
                                        showLogoutAlert = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                            Text("ออกจากระบบ")
                                                .font(.system(size: 15, weight: .semibold))
                                        }
                                        .foregroundColor(Color(hex: "#EF4444"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                                    }
                                    .padding(.bottom, 8)
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.formBackground)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                fetchStats()
                startUnreadListener()
            }
            .onDisappear {
                unreadListener?.remove()
            }
            .alert("ออกจากระบบ", isPresented: $showLogoutAlert) {
                    Button("ยกเลิก", role: .cancel) {}
                    Button("ออกจากระบบ", role: .destructive) {
                        do {
                            try Auth.auth().signOut()
                            userManager.isAdmin = false      // ← reset
                            userManager.username = ""
                            userManager.photoURL = ""
                            userManager.isLoading = true
                        } catch {
                            print("Logout error:", error.localizedDescription)
                        }
                    }
                } message: {
                    Text("คุณต้องการออกจากระบบใช่ไหม?")
                }
            }
    }

    // MARK: - Stat Card
    func statCard(title: String, value: String, icon: String, color: Color, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.darkText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    // MARK: - Menu Row
    func menuRow(icon: String, title: String, color: Color, destination: AnyView, badge: Int = 0) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(Color.darkText)

                Spacer()

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#EF4444"))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Fetch Stats
    func fetchStats() {
        let db = Firestore.firestore()
        let group = DispatchGroup()

        // โพสต์ found
        group.enter()
        db.collection("posts").whereField("type", isEqualTo: "found")
            .getDocuments { snap, _ in
                totalFound = snap?.documents.count ?? 0
                group.leave()
            }

        // โพสต์ lost
        group.enter()
        db.collection("posts").whereField("type", isEqualTo: "lost")
            .getDocuments { snap, _ in
                totalLost = snap?.documents.count ?? 0
                group.leave()
            }

        // users
        group.enter()
        db.collection("users").getDocuments { snap, _ in
            totalUsers = snap?.documents.count ?? 0
            group.leave()
        }

        // reports pending
        group.enter()
        db.collection("reports").whereField("status", isEqualTo: "pending")
            .getDocuments { snap, _ in
                pendingReports = snap?.documents.count ?? 0
                group.leave()
            }

        group.notify(queue: .main) {
            isLoading = false
        }
        // unread messages
        group.enter()
        db.collection("chats")
            .whereField("participants", arrayContains: AdminConstants.uid)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snap, _ in
                // นับเฉพาะที่ admin ไม่ได้เป็น sender (คือคนอื่นส่งมา)
                let count = snap?.documents.filter { doc in
                    let data = doc.data()
                    return (data["senderId"] as? String) != AdminConstants.uid
                }.count ?? 0
                unreadMessages = count
                group.leave()
            }
    }
    func startUnreadListener() {
        unreadListener?.remove()
        unreadListener = Firestore.firestore()
            .collection("chats")
            .whereField("participants", arrayContains: AdminConstants.uid)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snap, _ in
                let count = snap?.documents.filter { doc in
                    let data = doc.data()
                    return (data["senderId"] as? String) != AdminConstants.uid
                }.count ?? 0
                DispatchQueue.main.async {
                    unreadMessages = count
                }
            }
    }
}
