import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Model
struct NotificationItem: Identifiable {
    let id: String
    let title: String
    let desc: String
    let itemImage: String
    let postId: String
    let type: String
    var isRead: Bool
    let createdAt: Date
    
    let postTitle: String
    let detail: String
    let location: String
    let locationDetail: String
    let returnLocation: String
    let username: String
    let userId: String
    let date: String
    let images: [String]
    let category: String
}

// MARK: - View
struct NotifyView: View {
    
    @State private var notifications: [NotificationItem] = []
    @State private var listener: ListenerRegistration?
    @State private var navigateItem: NotificationItem?
    @State private var shouldNavigate = false
    @State private var isLoading = false
    @State private var freshNavigateItem: Item? = nil
    @State private var showDeletedAlert = false
    var body: some View {
        NavigationStack {
            ZStack {
                Color.formBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    ZStack {
                        Color.formBackground.ignoresSafeArea()
                        HStack {
                            Text("การแจ้งเตือน")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.loginTitle)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 50)
                    Divider()
                    
                    if notifications.isEmpty {
                       
                        Text("ยังไม่มีการแจ้งเตือน")
                          .foregroundColor(.gray)
                          .padding(.top, 50)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(notifications) { item in
                                    notifyRow(item: item)
                                }
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { startListening() }
            .onDisappear { listener?.remove() }
            .navigationDestination(isPresented: $shouldNavigate) {
                if let fresh = freshNavigateItem {
                    DetailView(item: fresh)
                }
            }
            .alert("โพสต์นี้ถูกลบแล้ว", isPresented: $showDeletedAlert) {
                Button("รับทราบ", role: .cancel) { }
            } message: {
                Text("โพสต์นี้ถูกปิดกั้นหรือลบออกจากระบบแล้ว ไม่สามารถดูรายละเอียดได้")
            }
        }
    }
    
    // MARK: - Row
    func notifyRow(item: NotificationItem) -> some View {
        Button {
            handlePress(item: item)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        ZStack {
                            Color(.systemGray5)
                            Image(systemName: "photo")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#5A4633"))
                        .multilineTextAlignment(.leading)
                    Text(item.desc)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                    Text(formatTime(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#bbbbbb"))
                        .padding(.top, 1)
                }

                Spacer()

                if !item.isRead {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(item.isRead ? Color.white : Color(hex: "#FFF3E6"))
            .overlay(
                Rectangle()
                    .fill(Color(hex: "#E0D6CC"))
                    .frame(height: 0.5),
                alignment: .bottom
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                deleteNotification(item)
            } label: {
                Label("ลบการแจ้งเตือน", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Delete
    func deleteNotification(_ item: NotificationItem) {
        guard let user = Auth.auth().currentUser else { return }
        withAnimation {
            notifications.removeAll { $0.id == item.id }
        }
        Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .collection("notifications")
            .document(item.id)
            .delete()
    }
    
    // MARK: - Firestore Listener
    func startListening() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        listener = db
            .collection("users")
            .document(user.uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self.notifications = docs.compactMap { doc in
                    let d = doc.data()
                    let ts = d["createdAt"] as? Timestamp
                    return NotificationItem(
                        id: doc.documentID,
                        title: d["title"] as? String ?? "มีการแจ้งเตือน",
                        desc: d["desc"] as? String ?? "",
                        itemImage: d["itemImage"] as? String ?? "",
                        postId: d["postId"] as? String ?? "",
                        type: d["type"] as? String ?? "found",
                        isRead: d["isRead"] as? Bool ?? false,
                        createdAt: ts?.dateValue() ?? Date(),
                        postTitle: d["postTitle"] as? String ?? "",
                        detail: d["detail"] as? String ?? "",
                        location: d["location"] as? String ?? "",
                        locationDetail: d["locationDetail"] as? String ?? "",
                        returnLocation: d["returnLocation"] as? String ?? "",
                        username: d["username"] as? String ?? "",
                        userId: d["userId"] as? String ?? "",
                        date: d["date"] as? String ?? "",
                        images: d["images"] as? [String] ?? [],
                        category: d["category"] as? String ?? ""
                    )
                }
            }
    }
    
    // MARK: - Handle Press
    func handlePress(item: NotificationItem) {
        guard let user = Auth.auth().currentUser, !isLoading else { return }
        let db = Firestore.firestore()
        

        // Mark as read
        db.collection("users")
            .document(user.uid)
            .collection("notifications")
            .document(item.id)
            .updateData(["isRead": true])

        if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
            notifications[idx].isRead = true
        }

        isLoading = true
        db.collection("posts").document(item.postId).getDocument { snap, _ in
            isLoading = false
            guard let data = snap?.data() else {
               
                showDeletedAlert = true
                return
            }

         
            let postStatus = data["status"] as? String ?? "waiting"
            if postStatus == "rejected" && item.type != "post_rejected_by_admin" {
                showDeletedAlert = true
                return
            }

            let freshItem = Item(
                id: item.postId,
                image: (data["images"] as? [String])?.first ?? "",
                images: data["images"] as? [String] ?? [],
                title: data["category"] as? String ?? item.postTitle,
                description: data["detail"] as? String ?? item.detail,
                location: data["location"] as? String ?? item.location,
                locationDetail: data["locationDetail"] as? String ?? item.locationDetail,
                latitude: data["latitude"] as? Double ?? 0,
                longitude: data["longitude"] as? Double ?? 0,
                returnLocation: data["returnLocation"] as? String ?? item.returnLocation,
                returnImage: data["returnImage"] as? String ?? "",
                username: data["username"] as? String ?? item.username,
                userId: data["userId"] as? String ?? item.userId,
                date: data["date"] as? String ?? item.date,
                type: data["type"] as? String ?? item.type,
                status: postStatus,
                userPhotoURL: data["userPhotoURL"] as? String ?? ""
            )
            navigateItem = item
            freshNavigateItem = freshItem
            shouldNavigate = true
        }
    }
    // MARK: - Format Time
    func formatTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "เมื่อสักครู่" }
        if diff < 3600 { return "\(diff / 60) นาทีที่แล้ว" }
        if diff < 86400 { return "\(diff / 3600) ชั่วโมงที่แล้ว" }
        return "\(diff / 86400) วันที่แล้ว"
    }
}
