import SwiftUI
import FirebaseFirestore

// MARK: - Model
struct AdminUser: Identifiable {
    let id: String
    var username: String
    var email: String
    var phone: String
    var createdAt: String
    var banned: Bool
    var postCount: Int = 0
    var reportCount: Int = 0
    var photoURL: String = ""
}

// MARK: - View
struct AdminUsersView: View {

    @Environment(\.dismiss) var dismiss
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var bannedFilter: BannedFilter = .all
    @State private var selectedUser: AdminUser? = nil
    //@State private var currentSelectedUser: AdminUser? = nil
    @State private var showBanConfirm = false
    @State private var actionLoading = false
    @State private var toastMessage: String? = nil

    enum BannedFilter: String, CaseIterable {
        case all = "ทั้งหมด"
        case active = "ปกติ"
        case banned = "ถูกแบน"
    }
    var currentSelectedUser: AdminUser? {
        guard let id = selectedUser?.id else { return nil }
        return users.first { $0.id == id }
    }
    var filteredUsers: [AdminUser] {
        users.filter { u in
            let matchFilter: Bool
            switch bannedFilter {
            case .all:    matchFilter = true
            case .active: matchFilter = !u.banned
            case .banned: matchFilter = u.banned
            }

            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            let matchSearch = q.isEmpty ||
                u.username.lowercased().contains(q) ||
                u.email.lowercased().contains(q) ||
                u.phone.contains(q)

            return matchFilter && matchSearch
        }
    }

    var bannedCount: Int { users.filter { $0.banned }.count }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {

                // HEADER
                ZStack {
                    Color.formBackground.ignoresSafeArea(edges: .top)
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Color.darkText)
                        }
                        Spacer()
                        Text("จัดการผู้ใช้")
                            .font(.headline)
                            .foregroundColor(Color.darkText)
                        Spacer()
                        Image(systemName: "chevron.left").opacity(0)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 50)

                Divider()

                // SUMMARY BAR
                HStack(spacing: 0) {
                    summaryBadge(title: "ทั้งหมด", value: users.count, color: .orange)
                    Divider().frame(height: 30)
                    summaryBadge(title: "ถูกแบน", value: bannedCount, color: Color(hex: "#EF4444"))
                }
                .background(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                // SEARCH + FILTER
                VStack(spacing: 10) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("ค้นหา username, email, เบอร์โทร", text: $searchText)
                            .font(.system(size: 14))
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(12)

                    // Filter tabs
                    HStack(spacing: 8) {
                        ForEach(BannedFilter.allCases, id: \.self) { f in
                            Button {
                                bannedFilter = f
                            } label: {
                                Text(f.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(bannedFilter == f ? Color.orange : Color.white)
                                    .foregroundColor(bannedFilter == f ? .white : .gray)
                                    .cornerRadius(20)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.formBackground)

                // LIST
                if isLoading {
                    Spacer()
                    ProgressView().tint(.orange)
                    Spacer()
                } else if filteredUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("ไม่พบผู้ใช้ที่ตรงกับเงื่อนไข")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredUsers) { user in
                                userCard(user)
                                    .onTapGesture {
                                        selectedUser = user
                                        showBanConfirm = false
                                    }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.formBackground)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { fetchUsers() }

            // TOAST
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#22C55E"))
                        .cornerRadius(14)
                        .shadow(radius: 8)
                        .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // BOTTOM SHEET
            if let user = currentSelectedUser {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedUser = nil
                        showBanConfirm = false
                    }

                VStack {
                    Spacer()
                    userDetailSheet(user)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(radius: 12)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedUser?.id)
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - User Card
    func userCard(_ user: AdminUser) -> some View {
        HStack(spacing: 14) {

            // Avatar
            avatarView(user, size: 46)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username.isEmpty ? "-" : user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.darkText)
                Text(user.email.isEmpty ? "-" : user.email)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Status badge
                Text(user.banned ? "ถูกแบน" : "ปกติ")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(user.banned ? Color(hex: "#EF4444").opacity(0.1) : Color(hex: "#22C55E").opacity(0.1))
                    .foregroundColor(user.banned ? Color(hex: "#EF4444") : Color(hex: "#16A34A"))
                    .cornerRadius(20)

                // Report badge
                if user.reportCount > 0 {
                    Text("🚩 \(user.reportCount) report")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "#EF4444"))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Detail Sheet
    func userDetailSheet(_ user: AdminUser) -> some View {
        VStack(spacing: 0) {

            // Handle bar
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Avatar + name
                    VStack(spacing: 10) {
                        avatarView(user, size: 64)
                        Text(user.username.isEmpty ? "-" : user.username)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.darkText)
                        Text(user.email)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)

                        Text(user.banned ? "🚫 ถูกแบน" : "ปกติ")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(user.banned ? Color(hex: "#EF4444").opacity(0.1) : Color(hex: "#22C55E").opacity(0.1))
                            .foregroundColor(user.banned ? Color(hex: "#EF4444") : Color(hex: "#16A34A"))
                            .cornerRadius(20)
                    }
                    .padding(.top, 8)

                    // Info
                    VStack(spacing: 0) {
                        infoRow(label: "User ID", value: user.id, mono: true)
                        Divider().padding(.leading, 16)
                        infoRow(label: "Username", value: user.username)
                        Divider().padding(.leading, 16)
                        infoRow(label: "Email", value: user.email)
                        Divider().padding(.leading, 16)
                        infoRow(label: "เบอร์โทร", value: user.phone.isEmpty ? "ยังไม่ได้เพิ่ม" : user.phone)
                        Divider().padding(.leading, 16)
                        infoRow(label: "วันที่สมัคร", value: user.createdAt)
                    }
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))

                    // Stats
                    HStack(spacing: 12) {
                        statBox(value: "\(user.postCount)", label: "โพสต์ทั้งหมด", color: .orange)
                        statBox(
                            value: "\(user.reportCount)",
                            label: "ถูก Report",
                            color: user.reportCount > 0 ? Color(hex: "#EF4444") : .gray
                        )
                    }

                    // Ban button
                    if !showBanConfirm {
                        Button {
                            showBanConfirm = true
                        } label: {
                            Text(user.banned ? "ปลดแบน User นี้" : "🚫 แบน User นี้")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(user.banned ? Color(hex: "#22C55E").opacity(0.1) : Color(hex: "#EF4444").opacity(0.1))
                                .foregroundColor(user.banned ? Color(hex: "#16A34A") : Color(hex: "#EF4444"))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(user.banned ? Color(hex: "#16A34A").opacity(0.3) : Color(hex: "#EF4444").opacity(0.3), lineWidth: 1)
                                )
                        }
                    } else {
                        // Confirm box
                        VStack(spacing: 12) {
                            Text(user.banned
                                 ? "ยืนยันปลดแบน \"\(user.username)\" ?"
                                 : "ยืนยันแบน \"\(user.username)\" ?\nUser จะไม่สามารถใช้งานแอปได้")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.darkText)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 10) {
                                Button {
                                    showBanConfirm = false
                                } label: {
                                    Text("ยกเลิก")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(Color.darkText)
                                        .cornerRadius(12)
                                }

                                Button {
                                    toggleBan(user)
                                } label: {
                                    Text(actionLoading ? "กำลังดำเนินการ..." : "ยืนยัน")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(user.banned ? Color(hex: "#16A34A") : Color(hex: "#EF4444"))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .disabled(actionLoading)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                }
                .padding(20)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
    }

    // MARK: - Sub Views
    func summaryBadge(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: mono ? .regular : .medium))
                .foregroundColor(Color.darkText)
                .lineLimit(mono ? 1 : nil)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray5), lineWidth: 1))
    }

    // MARK: - Firestore
    func fetchUsers() {
        let db = Firestore.firestore()

        db.collection("users").addSnapshotListener { snap, _ in
            guard let docs = snap?.documents else { return }

            // ดึง posts และ reports ก่อน แล้วคำนวณ count
            db.collection("posts").getDocuments { postSnap, _ in
                let posts = postSnap?.documents.map { ($0.documentID, $0.data()["userId"] as? String ?? "") } ?? []

                db.collection("reports").getDocuments { reportSnap, _ in
                    let reports = reportSnap?.documents.map { $0.data()["postId"] as? String ?? "" } ?? []

                    // postIds ของแต่ละ user
                    var postsByUser: [String: Set<String>] = [:]
                    for (postId, userId) in posts {
                        postsByUser[userId, default: []].insert(postId)
                    }

                    // นับ report ต่อ user
                    var reportCountByUser: [String: Int] = [:]
                    for postId in reports {
                        for (userId, postIds) in postsByUser {
                            if postIds.contains(postId) {
                                reportCountByUser[userId, default: 0] += 1
                                break
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        self.users = docs.map { doc in
                            let data = doc.data()
                            let uid = doc.documentID

                            // แปลง createdAt
                            var createdAtStr = "-"
                            if let ts = data["createdAt"] as? Timestamp {
                                let formatter = DateFormatter()
                                formatter.dateStyle = .medium
                                formatter.locale = Locale(identifier: "th_TH")
                                createdAtStr = formatter.string(from: ts.dateValue())
                            }

                            return AdminUser(
                                id: uid,
                                username: data["username"] as? String ?? "-",
                                email: data["email"] as? String ?? "-",
                                phone: data["phone"] as? String ?? "",
                                createdAt: createdAtStr,
                                banned: data["banned"] as? Bool ?? false,
                                postCount: postsByUser[uid]?.count ?? 0,
                                reportCount: reportCountByUser[uid] ?? 0,
                                photoURL: data["photoURL"] as? String ?? ""
                            )
                        }
                        .sorted { $0.username < $1.username }

                        self.isLoading = false
                    }
                }
            }
        }
    }

    func toggleBan(_ user: AdminUser) {
        actionLoading = true
        let newBanned = !user.banned
        Firestore.firestore().collection("users").document(user.id)
            .updateData(["banned": newBanned]) { error in
                DispatchQueue.main.async {
                    actionLoading = false
                    if error == nil {
                        selectedUser = nil
                        showBanConfirm = false
                        withAnimation {
                            toastMessage = newBanned
                                ? "แบน \(user.username) แล้ว"
                                : "ปลดแบน \(user.username) แล้ว"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { toastMessage = nil }
                        }
                    }
                }
            }
    }
    func avatarView(_ user: AdminUser, size: CGFloat) -> some View {
        Group {
            if !user.photoURL.isEmpty {
                AsyncImage(url: URL(string: user.photoURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure(_):
                        fallbackAvatar(user, size: size)
                    default:
                        ProgressView()
                    }
                }
            } else {
                fallbackAvatar(user, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(
                user.banned ? Color(hex: "#EF4444").opacity(0.4) : Color.orange.opacity(0.3),
                lineWidth: 1.5
            )
        )
    }

    func fallbackAvatar(_ user: AdminUser, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(user.banned ? Color(hex: "#EF4444").opacity(0.15) : Color.orange.opacity(0.15))
            Text(String(user.username.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(user.banned ? Color(hex: "#EF4444") : Color.orange)
        }
    }
}
