import SwiftUI

struct ChatView: View {
    
    @StateObject private var chatListVM = ChatListViewModel()
    
    var body: some View {
        VStack(spacing: 2) {
            
            // HEADER
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FFFAF5"), Color(hex: "#FFFAF5")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                HStack {
                    Text("แชท")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.loginTitle)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 50)
            Divider()
            
            // LIST
            ScrollView {
                VStack(spacing: 0) {
                    if chatListVM.recentChats.isEmpty {
                        Text("ยังไม่มีข้อความ")
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        ForEach(chatListVM.recentChats) { chat in
                            NavigationLink {
                                ChatDetailView(
                                    receiverId: chat.otherUserId,
                                    receiverName: chat.otherUsername,
                                    receiverPhotoURL: chat.otherUserPhotoURL
                                )
                            } label: {
                                chatRow(chat: chat)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    chatListVM.deleteChat(roomId: chat.id)
                                } label: {
                                    Label("ลบแชท", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.top,2)
            }
            Spacer()
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { chatListVM.fetchRecentChats() }
    }
}

extension ChatView {
    func chatRow(chat: RecentChat) -> some View {
        HStack(spacing: 20) {
            
            // แสดงรูปโปรไฟล์
            if let url = URL(string: chat.otherUserPhotoURL), !chat.otherUserPhotoURL.isEmpty {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                // fallback ตัวอักษรแรก
                ZStack {
                    Circle()
                        .fill(Color(hex: "#f8e8dc"))
                        .frame(width: 40, height: 40)
                    Text(String(chat.otherUsername.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#6E4D31"))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.otherUsername)
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .semibold))
                if let _ = chat.latestImageURL, chat.latestMessage.isEmpty {
                    Text("ส่งรูปภาพ")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text(chat.latestMessage)
                        .font(.caption)
                        .fontWeight(chat.hasUnread ? .bold : .regular)
                        .foregroundColor(chat.hasUnread ? .black : .gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if chat.hasUnread {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 15)
        .background(chat.hasUnread ? Color(hex: "#FFF3E6") : Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#5A4633").opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

#Preview {
    NavigationStack { ChatView() }
}
