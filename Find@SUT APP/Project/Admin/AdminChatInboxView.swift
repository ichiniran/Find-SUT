import SwiftUI
import _PhotosUI_SwiftUI
import FirebaseFirestore
import Combine
import PhotosUI
// MARK: - Models
struct AdminChatRoom: Identifiable {
    var id: String          // roomId
    var otherUserId: String
    var otherUsername: String
    var otherPhotoURL: String
    var lastMessage: String
    var lastTimestamp: Date
    var hasUnread: Bool
}



// MARK: - ViewModel
class AdminChatInboxViewModel: ObservableObject {
    @Published var rooms: [AdminChatRoom] = []
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    deinit { listener?.remove() }

    func startListening() {
        listener?.remove()
        listener = db.collection("chats")
            .whereField("participants", arrayContains: AdminConstants.uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                var dict: [String: AdminChatRoom] = [:]
                var userIdsToFetch: Set<String> = []

                for doc in docs {
                    let data = doc.data()
                    guard let roomId = data["roomId"] as? String else { continue }

                    let senderId   = data["senderId"]   as? String ?? ""
                    let receiverId = data["receiverId"] as? String ?? ""
                    let ts         = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    let isRead     = data["isRead"]     as? Bool ?? true
                    let type       = data["type"]       as? String ?? ""

                    let preview: String
                    switch type {
                    case "image":     preview = "ส่งรูปภาพ"
                    case "post_card": preview = "\(data["title"] as? String ?? "โพสต์")"
                    default:
                        if data["imageURL"] as? String != nil {
                            preview = "ส่งรูปภาพ"
                        } else {
                            preview = data["text"] as? String ?? "-"
                        }
                    }

                    let isMeAdmin = senderId == AdminConstants.uid
                    let otherUid  = isMeAdmin ? receiverId : senderId
                    let unread    = !isMeAdmin && !isRead

                    userIdsToFetch.insert(otherUid)

                    if var existing = dict[roomId] {
                        if ts > existing.lastTimestamp {
                            existing.lastMessage   = preview
                            existing.lastTimestamp = ts
                        }
                        if unread { existing.hasUnread = true }
                        dict[roomId] = existing
                    } else {
                        dict[roomId] = AdminChatRoom(
                            id: roomId,
                            otherUserId: otherUid,
                            otherUsername: "...",
                            otherPhotoURL: "",
                            lastMessage: preview,
                            lastTimestamp: ts,
                            hasUnread: unread
                        )
                    }
                }

                let group = DispatchGroup()
                var userMap: [String: (name: String, photo: String)] = [:]
                for uid in userIdsToFetch {
                    group.enter()
                    self.db.collection("users").document(uid).getDocument { snap, _ in
                        if let d = snap?.data() {
                            userMap[uid] = (
                                name:  d["username"] as? String ?? "ผู้ใช้",
                                photo: d["photoURL"]  as? String ?? ""
                            )
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    var finalDict = dict
                    for (roomId, room) in finalDict {
                        if let info = userMap[room.otherUserId] {
                            finalDict[roomId]?.otherUsername = info.name
                            finalDict[roomId]?.otherPhotoURL = info.photo
                        }
                    }
                    self.rooms = finalDict.values.sorted { $0.lastTimestamp > $1.lastTimestamp }
                }
            }
    }

    func stopListening() { listener?.remove() }
}

// MARK: - AdminChatInboxView (pushed via NavigationLink)
struct AdminChatInboxView: View {
    @StateObject private var vm = AdminChatInboxViewModel()
    @State private var selectedRoom: AdminChatRoom? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {

            // Header
            ZStack {
                Color.formBackground.ignoresSafeArea(edges: .top)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                    .foregroundColor(Color.darkText)
                    }
                     Spacer()
            VStack(spacing: 2) {
                 Text("กล่องข้อความ")
                  .font(.headline)
                  .foregroundColor(Color.darkText)
                let unread = vm.rooms.filter { $0.hasUnread }.count
               if unread > 0  {
              Text("ยังไม่ได้อ่าน \(unread) ข้อความ")
                  .font(.system(size: 11))
                     .foregroundColor(Color(hex: "#EF4444"))
            }
                }
            Spacer()
             Image(systemName: "chevron.left").opacity(0)
            }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)
            
            
            
            Divider()

            // List
            if vm.rooms.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(Color(.systemGray4))
                    Text("ยังไม่มีข้อความ")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(vm.rooms) { room in
                            Button { selectedRoom = room } label: {
                                roomRow(room: room)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 72)
                        }
                    }
                }
            }
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear  { vm.startListening() }
        .onDisappear { vm.stopListening() }
        // ── Sheet เปิดตอนกด room ──
        .sheet(item: $selectedRoom) { room in
            AdminChatDetailView(room: room)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Room Row
    func roomRow(room: AdminChatRoom) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle().fill(Color(hex: "#f8e8dc")).frame(width: 48, height: 48)
                if let url = URL(string: room.otherPhotoURL), !room.otherPhotoURL.isEmpty {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { ProgressView() }
                        .frame(width: 48, height: 48).clipShape(Circle())
                } else {
                    Text(String(room.otherUsername.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#6E4D31"))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(room.otherUsername)
                    .font(.system(size: 15, weight: room.hasUnread ? .bold : .semibold))
                    .foregroundColor(room.hasUnread ? .black : Color(hex: "#3d2b1f"))
                Text(room.lastMessage)
                    .font(.system(size: 13, weight: room.hasUnread ? .semibold : .regular))
                    .foregroundColor(room.hasUnread ? Color(hex: "#3d2b1f") : .gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(timeAgo(room.lastTimestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                if room.hasUnread {
                    Circle().fill(Color.orange).frame(width: 10, height: 10)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(room.hasUnread ? Color(hex: "#FFF8F3") : Color(.systemBackground))
    }

    func timeAgo(_ date: Date) -> String {
        let diff = Int(-date.timeIntervalSinceNow)
        if diff < 60    { return "เมื่อกี้" }
        if diff < 3600  { return "\(diff/60) นาที" }
        if diff < 86400 { return "\(diff/3600) ชม." }
        return "\(diff/86400) วัน"
    }
}

// MARK: - AdminChatDetailView (sheet)
struct AdminChatDetailView: View {
    let room: AdminChatRoom
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var imageToSend: UIImage? = nil
    @State private var navigateToPostId: String? = nil
    @State private var showPostsView = false
    
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var listener: ListenerRegistration?
    @State private var selectedImageURL: String?
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Handle + Header
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle().fill(Color(hex: "#f8e8dc")).frame(width: 38, height: 38)
                        if let url = URL(string: room.otherPhotoURL), !room.otherPhotoURL.isEmpty {
                            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                            placeholder: { ProgressView() }
                                .frame(width: 38, height: 38).clipShape(Circle())
                        } else {
                            Text(String(room.otherUsername.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#6E4D31"))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(room.otherUsername)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: "#3d2b1f"))
                        Text("ผู้ใช้งาน")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(.systemGray3))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .background(Color(hex: "#FFFAF5"))
            .overlay(Divider(), alignment: .bottom)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(messages) { msg in
                            messageBubble(msg: msg)
                        }
                        Color.clear.frame(height: 1).id("BOTTOM")
                    }
                    .padding(16)
                }
                .background(Color.formBackground)
                .scrollContentBackground(.hidden)
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
            }
            
            // IMAGE PREVIEW
            if let image = imageToSend {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(10)
                        .clipped()
                    Text("รูปที่เลือก")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Button {
                        imageToSend = nil
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.05), radius: 2)
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            
            // INPUT
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                }
                .onChange(of: selectedPhoto) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            imageToSend = uiImage
                        }
                    }
                }
                
                TextField("พิมพ์ข้อความตอบกลับ...", text: $messageText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .onSubmit { sendReply() }
                
                Button { sendReply() } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            messageText.trimmingCharacters(in: .whitespaces).isEmpty && imageToSend == nil
                            ? Color.gray.opacity(0.3) : Color.orange
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty && imageToSend == nil)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemBackground))
            .overlay(Divider(), alignment: .top)
        }
        .background(Color.formBackground)
        .onAppear  { startListening() }
        .onDisappear { listener?.remove() }
        .sheet(isPresented: $showPostsView) {
            if let postId = navigateToPostId {
                NavigationStack {
                    AdminPostsView(initialPostId: postId)
                }
            }
        }
        // full-screen image viewer — overlay แทน nested sheet
        .overlay {
            if let imageURL = selectedImageURL {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .onTapGesture { selectedImageURL = nil }
                    
                    
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit().ignoresSafeArea()
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    
                    // ปุ่มปิด
                    VStack {
                        HStack {
                            Spacer()
                            Button { selectedImageURL = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(16)
                            }
                        }
                        Spacer()
                    }
                }
                .zIndex(999)
            }
        }
    }
    
    // MARK: - Bubble
    @ViewBuilder
    func messageBubble(msg: ChatMessage) -> some View {
        let isAdmin = msg.senderId == AdminConstants.uid
        HStack(alignment: .bottom, spacing: 8) {
            if isAdmin { Spacer() }
            VStack(alignment: isAdmin ? .trailing : .leading, spacing: 4) {
                // shared post card
                if let itemData = msg.sharedItemData {
                    sharedPostCard(itemData: itemData)
                        .onTapGesture {
                            if let postId = itemData["id"] as? String {
                                navigateToPostId = postId
                                showPostsView = true
                            }
                        }
                }                // image
                if let imageURL = msg.imageURL, let url = URL(string: imageURL) {
                    Button { selectedImageURL = imageURL } label: {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                                    .frame(width: 200, height: 200).clipped().cornerRadius(16)
                            } else {
                                Color.gray.opacity(0.15).frame(width: 200, height: 200).cornerRadius(16)
                            }
                        }
                    }
                }
                // text
                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(isAdmin ? Color.orange : Color.white)
                        .foregroundColor(isAdmin ? .white : Color(hex: "#3d2b1f"))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isAdmin ? Color.clear : Color(hex: "#EEEEEE"), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: 260, alignment: isAdmin ? .trailing : .leading)
            if !isAdmin { Spacer() }
        }
    }
    
    // MARK: - Post card
    func sharedPostCard(itemData: [String: Any]) -> some View {
        let type  = itemData["type"]     as? String ?? "found"
        let title = itemData["title"]    as? String ?? "-"
        let loc   = itemData["location"] as? String ?? "-"
        let date  = itemData["date"]     as? String ?? "-"
        let img   = itemData["image"]    as? String ?? ""
        
        return VStack(alignment: .leading, spacing: 0) {
            if !img.isEmpty, let url = URL(string: img) {
                AsyncImage(url: url) { phase in
                    if let i = phase.image { i.resizable().scaledToFill() }
                    else { Color.gray.opacity(0.15) }
                }
                .frame(height: 100).frame(maxWidth: .infinity).clipped()
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(type == "found" ? "พบของ" : "ของหาย")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(type == "found" ? Color.orange : Color.red)
                    .cornerRadius(6)
                Text(title).font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#3d2b1f")).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "mappin").font(.system(size: 10)).foregroundColor(.red)
                    Text(loc).font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 10)).foregroundColor(.gray)
                    Text(date).font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            .padding(10)
        }
        .frame(width: 220)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#f0e6dc"), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }
    
    // MARK: - Firestore
    func startListening() {
        listener?.remove()
        listener = db.collection("chats")
            .whereField("roomId", isEqualTo: room.id)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                var msgs = docs.compactMap { doc -> ChatMessage? in
                    let d = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        roomId:     d["roomId"]     as? String ?? "",
                        senderId:   d["senderId"]   as? String ?? "",
                        receiverId: d["receiverId"] as? String ?? "",
                        text:       d["text"]       as? String ?? "",
                        timestamp:  (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead:     d["isRead"]     as? Bool ?? false,
                        sharedItemData: d["sharedItem"] as? [String: Any],
                        imageURL:   d["imageURL"]   as? String
                    )
                }
                msgs.sort { $0.timestamp < $1.timestamp }
                DispatchQueue.main.async { self.messages = msgs }
                
                // Mark as read
                docs.forEach { doc in
                    let d = doc.data()
                    if (d["receiverId"] as? String) == AdminConstants.uid,
                       (d["isRead"] as? Bool) == false {
                        doc.reference.updateData(["isRead": true])
                    }
                }
            }
    }
    
    func sendReply() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || imageToSend != nil else { return }
        messageText = ""
        let imageSnapshot = imageToSend
        imageToSend = nil
        selectedPhoto = nil
        
        Task {
            var imageURL: String? = nil
            if let img = imageSnapshot {
                imageURL = await uploadToCloudinary(image: img)
            }
            
            var data: [String: Any] = [
                "roomId":       room.id,
                "senderId":     AdminConstants.uid,
                "receiverId":   room.otherUserId,
                "senderName":   AdminConstants.name,
                "receiverName": room.otherUsername,
                "text":         text,
                "type":         imageURL != nil ? "image" : "text",
                "isRead":       false,
                "timestamp":    Timestamp(date: Date()),
                "participants": [AdminConstants.uid, room.otherUserId],
                "hiddenFor":    []
            ]
            if let url = imageURL { data["imageURL"] = url }
            try? await db.collection("chats").addDocument(data: data)
        }
    }
    
    func uploadToCloudinary(image: UIImage) async -> String? {
        let resized = image.resized(toWidth: 800) ?? image
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }
        
        let url = URL(string: "https://api.cloudinary.com/v1_1/dy9lc24op/image/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n")
        append("findsut\r\n")
        append("--\(boundary)--\r\n")
        req.httpBody = body
        
        do {
            let (resData, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: resData) as? [String: Any]
            return json?["secure_url"] as? String
        } catch {
            return nil
        }
    }
}
