import SwiftUI
import FirebaseFirestore

// MARK: - Models
struct AdminPost: Identifiable {
    let id: String
    let type: String
    let category: String
    let detail: String
    let images: [String]
    let location: String
    let locationDetail: String
    let returnLocation: String
    let returnImage: String
    let date: String
    var status: String
    let userId: String
    let username: String
    let latitude: Double
    let longitude: Double
    let claimedBy: String
    let claimedByName: String
    let claimedByPhone: String
    let createdAt: Date?
}

// MARK: - View
struct AdminPostsView: View {
    var initialPostId: String = ""
    @Environment(\.dismiss) var dismiss
    @State private var posts: [AdminPost] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var statusFilter: PostStatusFilter = .all
    @State private var typeFilter: PostTypeFilter = .all
    @State private var selectedPost: AdminPost? = nil
    @State private var ownerInfo: (username: String, email: String)? = nil
    @State private var claimerInfo: (username: String, phone: String)? = nil
    @State private var postLoading = false
    @State private var actionLoading = false
    @State private var showDeleteConfirm = false
    @State private var postToDelete: AdminPost? = nil
    @State private var toastMessage: String? = nil
    @State private var toastIsError = false
    @State private var previewImageURL: String? = nil
    
    enum PostStatusFilter: String, CaseIterable {
        case all      = "ทั้งหมด"
        case waiting  = "รอดำเนินการ"
        case claimed  = "มีคนรับแล้ว"
        case rejected = "ลบออก"

        var key: String {
            switch self {
            case .all: return "all"
            case .waiting: return "waiting"
            case .claimed: return "claimed"
            case .rejected: return "rejected"
            }
        }
    }

    enum PostTypeFilter: String, CaseIterable {
        case all   = "ทุกประเภท"
        case found = "พบของ"
        case lost  = "ของหาย"

        var key: String {
            switch self {
            case .all: return "all"
            case .found: return "found"
            case .lost: return "lost"
            }
        }
    }

    struct StatusConfig {
        let label: String
        let bg: Color
        let color: Color
        let border: Color
    }

    let statusConfigs: [String: StatusConfig] = [
        "waiting":  StatusConfig(label: "รอดำเนินการ",   bg: Color(hex: "#FFF3E0"), color: Color(hex: "#E65100"), border: Color(hex: "#FFCC80")),
        "claimed":  StatusConfig(label: "มีคนรับแล้ว",  bg: Color(hex: "#E8F5E9"), color: Color(hex: "#2E7D32"), border: Color(hex: "#A5D6A7")),
        "rejected": StatusConfig(label: "ลบออก (report)", bg: Color(hex: "#FFEBEE"), color: Color(hex: "#C62828"), border: Color(hex: "#EF9A9A"))
    ]

    var filteredPosts: [AdminPost] {
        posts.filter { p in
            let matchStatus = statusFilter.key == "all" || p.status == statusFilter.key
            let matchType   = typeFilter.key == "all"   || p.type == typeFilter.key
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            let matchSearch = q.isEmpty ||
                p.category.lowercased().contains(q) ||
                p.location.lowercased().contains(q) ||
                p.username.lowercased().contains(q) ||
                p.id.lowercased().contains(q)
            return matchStatus && matchType && matchSearch
        }
    }

    var statsWaiting:  Int { posts.filter { $0.status == "waiting"  }.count }
    var statsClaimed:  Int { posts.filter { $0.status == "claimed"  }.count }
    var statsRejected: Int { posts.filter { $0.status == "rejected" }.count }

    // MARK: - Body
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
                        Text("จัดการโพสต์")
                            .font(.headline)
                            .foregroundColor(Color.darkText)
                        Spacer()
                        Image(systemName: "chevron.left").opacity(0)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 50)

                Divider()

                // STATS BAR
                HStack(spacing: 0) {
                    statsBadge(label: "รอดำเนินการ", value: statsWaiting,  color: Color(hex: "#E65100"))
                    Divider().frame(height: 30)
                    statsBadge(label: "มีคนรับแล้ว", value: statsClaimed,  color: Color(hex: "#2E7D32"))
                    Divider().frame(height: 30)
                    statsBadge(label: "ลบออก",        value: statsRejected, color: Color(hex: "#C62828"))
                }
                .background(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                // FILTER
                VStack(spacing: 10) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("ค้นหา หมวดหมู่, สถานที่, username, Post ID", text: $searchText)
                            .font(.system(size: 14))
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(12)

                    // Status tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PostStatusFilter.allCases, id: \.self) { f in
                                Button {
                                    statusFilter = f
                                } label: {
                                    Text(f.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(statusFilter == f ? Color.orange : Color.white)
                                        .foregroundColor(statusFilter == f ? .white : .gray)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }

                    // Type tabs
                    HStack(spacing: 8) {
                        ForEach(PostTypeFilter.allCases, id: \.self) { f in
                            Button {
                                typeFilter = f
                            } label: {
                                Text(f.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(typeFilter == f ? Color(hex: "#5A4633") : Color.white)
                                    .foregroundColor(typeFilter == f ? .white : .gray)
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
                } else if filteredPosts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("ไม่พบโพสต์ที่ตรงกับเงื่อนไข")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredPosts) { post in
                                postCard(post)
                                    .onTapGesture { openDetail(post) }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.formBackground)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                       fetchPosts()
                       if !initialPostId.isEmpty {
                           searchText = initialPostId
                       }
                   }
            
            .alert("ยืนยันการลบโพสต์", isPresented: $showDeleteConfirm) {
                  Button("ยกเลิก", role: .cancel) {
                      postToDelete = nil
                  }
                  Button("ลบ", role: .destructive) {
                      if let post = postToDelete {
                          handleDelete(post)
                      }
                  }
              } message: {
                  Text("โพสต์นี้จะถูกลบถาวร")
              }
          
            // TOAST
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text(toastIsError ? "" : "")
                        Text(msg)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(toastIsError ? Color(hex: "#EF4444") : Color(hex: "#22C55E"))
                    .cornerRadius(14)
                    .shadow(radius: 8)
                    .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // BOTTOM SHEET
            if selectedPost != nil {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedPost = nil
                        showDeleteConfirm = false
                    }

                VStack {
                    Spacer()
                    postDetailSheet
                        .background(Color(hex: "#FFFAF5"))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(radius: 12)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }

            // DELETE CONFIRM SHEET
            /*if showDeleteConfirm, let post = postToDelete {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showDeleteConfirm = false }

                VStack {
                    Spacer()
                    deleteConfirmSheet(post)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(radius: 12)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }*/

            // IMAGE PREVIEW
            if let url = previewImageURL {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture { previewImageURL = nil }
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFit().padding(20)
                    default: ProgressView()
                    }
                }
                VStack {
                    HStack {
                        Spacer()
                        Button { previewImageURL = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                        }
                    }
                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedPost?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showDeleteConfirm)
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - Post Card
    func postCard(_ post: AdminPost) -> some View {
        HStack(spacing: 14) {

            // Thumbnail
            if let firstImg = post.images.first, !firstImg.isEmpty {
                AsyncImage(url: URL(string: firstImg)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(10)
                .clipped()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 5) {
                // Type + Status
                HStack(spacing: 6) {
                    typeBadgeView(post.type)
                    if let cfg = statusConfigs[post.status] {
                        Text(cfg.label)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(cfg.bg)
                            .foregroundColor(cfg.color)
                            .cornerRadius(20)
                    }
                }

                Text(post.category.isEmpty ? "ไม่ระบุหมวดหมู่" : post.category)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#5A4633"))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(post.location.isEmpty ? "-" : post.location)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Text("@\(post.username.isEmpty ? "-" : post.username)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#a0856a"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(post.date.isEmpty ? "-" : post.date)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                // Delete button
                Button {
                    postToDelete = post
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#C62828"))
                        .padding(8)
                        .background(Color(hex: "#FFEBEE"))
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Detail Sheet
    var postDetailSheet: some View {
        VStack(spacing: 0) {

            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("ข้อมูลโพสต์")
                        .font(.headline)
                        .foregroundColor(Color.darkText)
                        .padding(.top, 20)
                    // Type + Status badges
                    if let post = selectedPost {
                        HStack(spacing: 8) {
                            typeBadgeView(post.type)
                            if let cfg = statusConfigs[post.status] {
                                Text(cfg.label)
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(cfg.bg)
                                    .foregroundColor(cfg.color)
                                    .cornerRadius(20)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Images
                        if !post.images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(post.images.prefix(4), id: \.self) { imgUrl in
                                        AsyncImage(url: URL(string: imgUrl)) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                            default:
                                                Color(.systemGray5)
                                            }
                                        }
                                        .frame(width: 90, height: 90)
                                        .cornerRadius(10)
                                        .clipped()
                                        .onTapGesture { previewImageURL = imgUrl }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Post Info
                        sectionCard(title: "ข้อมูลโพสต์") {
                            if postLoading {
                                HStack {
                                    Spacer()
                                    ProgressView().tint(.orange)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            } else {
                                infoRow(label: "Post ID", value: post.id, mono: true)
                                Divider().padding(.leading, 16)
                                infoRow(label: "เจ้าของโพสต์", value: ownerInfo?.username.isEmpty == false ? "@\(ownerInfo!.username)" : (ownerInfo?.email ?? post.username))
                                Divider().padding(.leading, 16)
                                infoRow(label: "หมวดหมู่", value: post.category.isEmpty ? "-" : post.category)
                                Divider().padding(.leading, 16)
                                infoRow(label: "รายละเอียด", value: post.detail.isEmpty ? "-" : post.detail)
                                Divider().padding(.leading, 16)
                                infoRow(label: "วันที่", value: post.date.isEmpty ? "-" : post.date)
                                Divider().padding(.leading, 16)
                                infoRow(label: "สถานที่", value: post.location.isEmpty ? "-" : post.location)
                                if !post.locationDetail.isEmpty {
                                    Divider().padding(.leading, 16)
                                    infoRow(label: "รายละเอียดสถานที่", value: post.locationDetail)
                                }
                                if !post.returnLocation.isEmpty {
                                    Divider().padding(.leading, 16)
                                    infoRow(label: "สถานที่รับคืน", value: post.returnLocation)
                                }
                                if post.status == "claimed" {
                                    Divider().padding(.leading, 16)
                                    infoRow(label: "รับโดย", value: claimerInfo?.username.isEmpty == false ? "@\(claimerInfo!.username)" : post.claimedByName)
                                    Divider().padding(.leading, 16)
                                    infoRow(label: "เบอร์คนรับ", value: claimerInfo?.phone ?? post.claimedByPhone)
                                }
                            }
                        }

                        // Map link
                        if post.latitude != 0 && post.longitude != 0 {
                            Button {
                                let urlStr = "https://maps.apple.com/?q=\(post.latitude),\(post.longitude)"
                                if let url = URL(string: urlStr) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                    Text("เปิดแผนที่")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#F97316"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#FFF7F0"))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DC"), lineWidth: 1))
                            }
                            .padding(.horizontal, 16)
                        }

                        // Change Status
                        sectionCard(title: "เปลี่ยนสถานะ") {
                            HStack(spacing: 8) {
                                ForEach(["waiting", "claimed", "rejected"], id: \.self) { st in
                                    if let cfg = statusConfigs[st] {
                                        Button {
                                            handleChangeStatus(post, newStatus: st)
                                        } label: {
                                            Text(cfg.label)
                                                .font(.system(size: 12, weight: .bold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(post.status == st ? cfg.bg : Color.white)
                                                .foregroundColor(cfg.color)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(post.status == st ? cfg.border : Color(.systemGray4), lineWidth: post.status == st ? 2 : 1)
                                                )
                                        }
                                        .disabled(actionLoading || post.status == st)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // Delete button
                        Button {
                            postToDelete = post
                            selectedPost = nil
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("ลบโพสต์นี้ออกจากระบบ")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#C62828"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#FFEBEE"))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#EF9A9A"), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
    }

    // MARK: - Delete Confirm Sheet
    func deleteConfirmSheet(_ post: AdminPost) -> some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Text("ยืนยันการลบโพสต์")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#5A4633"))
                Text("โพสต์นี้จะถูกลบออกจากระบบถาวร\nไม่สามารถกู้คืนได้")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button {
                    showDeleteConfirm = false
                    postToDelete = nil
                } label: {
                    Text("ยกเลิก")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .foregroundColor(Color(hex: "#5A4633"))
                        .cornerRadius(14)
                }

                Button {
                    handleDelete(post)
                } label: {
                    Text(actionLoading ? "กำลังลบ..." : "ลบโพสต์")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#EF4444"))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(actionLoading)
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sub Views
    func statsBadge(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    func typeBadgeView(_ type: String) -> some View {
        Text(type == "found" ? "พบของ" : "ของหาย")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(type == "found" ? Color(hex: "#E8F5E9") : Color(hex: "#FFF3E0"))
            .foregroundColor(type == "found" ? Color(hex: "#2E7D32") : Color(hex: "#E65100"))
            .cornerRadius(20)
    }

    func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#a0856a"))
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#F0E6DC"), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13, weight: mono ? .regular : .medium))
                .foregroundColor(Color(hex: "#5A4633"))
                .lineLimit(mono ? 1 : 4)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "th_TH")
        return f.string(from: date)
    }

    func showToast(_ msg: String, isError: Bool = false) {
        toastIsError = isError
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Firestore
    func fetchPosts() {
        Firestore.firestore().collection("posts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                DispatchQueue.main.async {
                    self.posts = docs.map { doc in
                        let data = doc.data()
                        return AdminPost(
                            id: doc.documentID,
                            type: data["type"] as? String ?? "",
                            category: data["category"] as? String ?? "",
                            detail: data["detail"] as? String ?? "",
                            images: data["images"] as? [String] ?? [],
                            location: data["location"] as? String ?? "",
                            locationDetail: data["locationDetail"] as? String ?? "",
                            returnLocation: data["returnLocation"] as? String ?? "",
                            returnImage: data["returnImage"] as? String ?? "",
                            date: data["date"] as? String ?? "",
                            status: data["status"] as? String ?? "waiting",
                            userId: data["userId"] as? String ?? "",
                            username: data["username"] as? String ?? "",
                            latitude: data["latitude"] as? Double ?? 0,
                            longitude: data["longitude"] as? Double ?? 0,
                            claimedBy: data["claimedBy"] as? String ?? "",
                            claimedByName: data["claimedByName"] as? String ?? "",
                            claimedByPhone: data["claimedByPhone"] as? String ?? "",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                        )
                    }
                    self.isLoading = false
                }
            }
    }

    func openDetail(_ post: AdminPost) {
        selectedPost = post
        ownerInfo = nil
        claimerInfo = nil
        postLoading = true

        let db = Firestore.firestore()

        db.collection("users").document(post.userId).getDocument { snap, _ in
            if let data = snap?.data() {
                DispatchQueue.main.async {
                    self.ownerInfo = (
                        username: data["username"] as? String ?? "",
                        email: data["email"] as? String ?? ""
                    )
                }
            }
            // ดึง claimer ถ้ามี
            if !post.claimedBy.isEmpty {
                db.collection("users").document(post.claimedBy).getDocument { cSnap, _ in
                    if let cData = cSnap?.data() {
                        DispatchQueue.main.async {
                            self.claimerInfo = (
                                username: cData["username"] as? String ?? "",
                                phone: cData["phone"] as? String ?? ""
                            )
                        }
                    }
                    DispatchQueue.main.async { self.postLoading = false }
                }
            } else {
                DispatchQueue.main.async { self.postLoading = false }
            }
        }
    }

    func handleChangeStatus(_ post: AdminPost, newStatus: String) {
        actionLoading = true
        Firestore.firestore().collection("posts").document(post.id)
            .updateData([
                "status": newStatus,
                "updatedAt": Timestamp(date: Date())
            ]) { error in
                DispatchQueue.main.async {
                    actionLoading = false
                    if error == nil {
                        let label = statusConfigs[newStatus]?.label ?? newStatus
                        showToast("เปลี่ยนสถานะเป็น \"\(label)\" แล้ว")
                        selectedPost = nil
                    } else {
                        showToast("เกิดข้อผิดพลาด กรุณาลองใหม่", isError: true)
                    }
                }
            }
    }

    func handleDelete(_ post: AdminPost) {
        actionLoading = true
        Firestore.firestore().collection("posts").document(post.id)
            .delete { error in
                DispatchQueue.main.async {
                    actionLoading = false
                    showDeleteConfirm = false
                    postToDelete = nil
                    if error == nil {
                        showToast("ลบโพสต์เรียบร้อยแล้ว")
                        selectedPost = nil
                    } else {
                        showToast("เกิดข้อผิดพลาด กรุณาลองใหม่", isError: true)
                    }
                }
            }
    }
}
