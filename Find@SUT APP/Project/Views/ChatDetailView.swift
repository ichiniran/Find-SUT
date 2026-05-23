import SwiftUI
import FirebaseFirestore
import PhotosUI
struct ChatDetailView: View {
    
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var imageToSend: UIImage? = nil
   
    @State private var selectedImage: ImageViewerItem? = nil
    
    var receiverId: String
    var receiverName: String
    var receiverPhotoURL: String = ""
    
    @State private var selectedItem: Item? = nil
    @State var itemToShare: Item? = nil
    @StateObject private var chatVM = ChatViewModel()
    
    struct ImageViewerItem: Identifiable {
        let id = UUID()
        let url: String
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── HEADER ──
            ZStack {
                Color.formBackground.ignoresSafeArea(edges: .top)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").foregroundColor(Color.darkText)
                    }
                    Spacer()
                    Text(receiverName).foregroundColor(Color.darkText).font(.headline)
                    Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 60)
            .overlay(
                Rectangle().fill(Color(hex: "#5A4633").opacity(0.3)).frame(height: 1),
                alignment: .bottom
            )
            
            // ── CHAT AREA ──
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(chatVM.messages) { msg in
                            messageBubble(msg: msg)
                        }
                    }
                    .padding()
                    .id("CHAT_BOTTOM")
                }
                .onChange(of: chatVM.messages.count) { _ in
                    withAnimation { proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom) }
                }
            }
            
            // ── BANNER PREVIEW ──
            if let item = itemToShare {
                HStack {
                    if let firstImage = item.images.first, let url = URL(string: firstImage) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                        .clipped()
                    }
                    VStack(alignment: .leading) {
                        Text("แนบโพสต์:").font(.caption).foregroundColor(.gray)
                        Text(item.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    }
                    Spacer()
                    Button { itemToShare = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.05), radius: 2)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            // ── IMAGE PREVIEW ──
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
                .padding(.top, 8)
            }
            // ── INPUT AREA ──
            HStack {
                // ปุ่มเลือกรูป
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                .onChange(of: selectedPhoto) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            imageToSend = uiImage
                        }
                    }
                }
                
                TextField("พิมพ์ข้อความ", text: $messageText)
                    .padding()
                    .font(.system(size: 14))
                    .background(Color.white)
                    .cornerRadius(20)
                    .onSubmit { handleSend() }
                
                Button { handleSend() } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            messageText.trimmingCharacters(in: .whitespaces).isEmpty
                            && itemToShare == nil
                            && imageToSend == nil
                            ? Color.gray : Color.orange
                        )
                        .clipShape(Circle())
                }
                .disabled(
                    messageText.trimmingCharacters(in: .whitespaces).isEmpty
                    && itemToShare == nil
                    && imageToSend == nil
                )
            }            .padding()
            .background(Color.formBackground)
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            setTabBar(hidden: true)
            chatVM.fetchMessages(with: receiverId)
        }
        .onDisappear {
            setTabBar(hidden: false)
            chatVM.stopListening()
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                DetailView(item: item)
                    .environmentObject(BookmarkManager())
            }
        }
        .sheet(item: $selectedImage) { item in
            ZStack {
                // พื้นหลังดำ
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedImage = nil
                    }

                // รูปภาพ
                AsyncImage(url: URL(string: item.url)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }

                // ปุ่มปิด
                VStack {
                    HStack {
                        Spacer()

                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(16)
                        }
                    }

                    Spacer()
                }
            }
            .presentationBackground(.clear) // สำคัญ
        }
        
    }
    func setTabBar(hidden: Bool) {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                let tabBar = window.rootViewController?.findTabBarController()
                print("TabBar found: \(tabBar != nil)") // ← เช็คตรงนี้
                tabBar?.tabBar.isHidden = hidden
            }
        }
    }
    private func handleSend() {
        let textToSend = messageText.trimmingCharacters(in: .whitespaces)
        chatVM.sendMessage(
            text: textToSend,
            receiverId: receiverId,
            receiverName: receiverName,
            receiverPhotoURL: receiverPhotoURL,  
            itemToShare: itemToShare,
            image: imageToSend
        )
        messageText = ""
        itemToShare = nil
        imageToSend = nil
        selectedPhoto = nil
    }
}

// MARK: - UI COMPONENTS
extension ChatDetailView {
    
    func messageBubble(msg: ChatMessage) -> some View {
        HStack {
            if msg.isMe { Spacer() }
            
            VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 4) {
                
                if let itemData = msg.sharedItemData {
                    let postId = itemData["id"] as? String ?? ""
                    Button {
                        Firestore.firestore().collection("posts").document(postId).getDocument { snap, _ in
                            guard let data = snap?.data() else { return }
                            let freshItem = Item(
                                id: postId,
                                image: (data["images"] as? [String])?.first ?? "",
                                images: data["images"] as? [String] ?? [],
                                title: data["category"] as? String ?? "",
                                description: data["detail"] as? String ?? "",
                                location: data["location"] as? String ?? "",
                                locationDetail: data["locationDetail"] as? String ?? "",
                                latitude: data["latitude"] as? Double ?? 0,
                                longitude: data["longitude"] as? Double ?? 0,
                                returnLocation: data["returnLocation"] as? String ?? "",
                                returnImage: data["returnImage"] as? String ?? "",
                                username: data["username"] as? String ?? "",
                                userId: data["userId"] as? String ?? "",
                                date: data["date"] as? String ?? "",
                                type: data["type"] as? String ?? "found",
                                status: data["status"] as? String ?? "waiting",
                                userPhotoURL: data["userPhotoURL"] as? String ?? ""
                            )
                            DispatchQueue.main.async { selectedItem = freshItem }
                        }
                    } label: {
                        sharedItemCard(itemData: itemData)
                    }
                    .buttonStyle(.plain)
                }
                // แสดงรูปที่ส่ง
                if let imageURL = msg.imageURL, let url = URL(string: imageURL) {
                    Button {
                        selectedImage = ImageViewerItem(url: imageURL)
                    } label: {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: 200)
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(16)
                            } else {
                                ProgressView()
                                    .frame(width: 200, height: 180)
                            }
                        }
                    }
                }
                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(msg.isMe ? Color.orange : Color.white)
                        .foregroundColor(msg.isMe ? .white : Color(hex: "#3d2b1f"))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                            .stroke(msg.isMe ? Color.clear : Color(hex: "#EEEEEE"), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: 260, alignment: msg.isMe ? .trailing : .leading)
            
            if !msg.isMe { Spacer() }
        }
    }
    
    func sharedItemCard(itemData: [String: Any]) -> some View {
        let type = itemData["type"] as? String ?? "found"
        let title = itemData["title"] as? String ?? "ไม่มีชื่อ"
        let location = itemData["location"] as? String ?? "ไม่ระบุ"
        let date = itemData["date"] as? String ?? "-"
        let imageStr = itemData["image"] as? String ?? ""
        
        return VStack(alignment: .leading, spacing: 0) {
            if !imageStr.isEmpty, let url = URL(string: imageStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(type == "found" ? "พบของ" : "ของหาย")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(type == "found" ? Color.orange : Color.red)
                    .cornerRadius(8)
                
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin").foregroundColor(.red).font(.system(size: 12))
                        Text(location).font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").foregroundColor(.gray).font(.system(size: 12))
                        Text(date).font(.system(size: 12)).foregroundColor(.gray)
                    }
                }
                
                Text("แตะเพื่อดูรายละเอียด ->")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 4)
    }
}

#Preview {
    ChatDetailView(receiverId: "dummy", receiverName: "Ohm")
}
