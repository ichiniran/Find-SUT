import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct RecentChat: Identifiable {
    var id: String
    var otherUserId: String
    var otherUsername: String
    var otherUserPhotoURL: String  
    var latestMessage: String
    var latestImageURL: String?
    var timestamp: Date
    var hasUnread: Bool
    
}

class ChatListViewModel: ObservableObject {
    @Published var recentChats: [RecentChat] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    func fetchRecentChats() {
        listener?.remove()
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        listener = db.collection("chats")
            .whereField("participants", arrayContains: currentUserID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

                var chatDict: [String: RecentChat] = [:]
                var userIdsToFetch: Set<String> = []

                for doc in documents {
                    let data = doc.data()
                    let roomId = data["roomId"] as? String ?? ""
                    let senderId = data["senderId"] as? String ?? ""
                    let receiverId = data["receiverId"] as? String ?? ""
                    let text = data["text"] as? String ?? ""
                    let imageURL = data["imageURL"] as? String
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let isRead = data["isRead"] as? Bool ?? false

                    let isMeSender = (senderId == currentUserID)
                    let otherUserId = isMeSender ? receiverId : senderId
                    let otherPhotoURL = isMeSender
                        ? (data["receiverPhotoURL"] as? String ?? "")
                        : (data["senderPhotoURL"] as? String ?? "")
                    let unread = (!isMeSender && !isRead)

                    userIdsToFetch.insert(otherUserId)

                    if let existingChat = chatDict[roomId] {
                        var updatedChat = existingChat
                        if timestamp > existingChat.timestamp {
                            updatedChat.latestMessage = text
                            updatedChat.latestImageURL = imageURL
                            updatedChat.timestamp = timestamp
                        }
                        if unread { updatedChat.hasUnread = true }
                        chatDict[roomId] = updatedChat
                    } else {
                        chatDict[roomId] = RecentChat(
                            id: roomId,
                            otherUserId: otherUserId,
                            otherUsername: "...",
                            otherUserPhotoURL: otherPhotoURL,
                            latestMessage: text,
                            latestImageURL: imageURL,
                            timestamp: timestamp,
                            hasUnread: unread
                        )
                    }
                }

                // ดึง users ทุกคนพร้อมกันใน batch เดียว
                let group = DispatchGroup()
                var userMap: [String: (name: String, photo: String)] = [:]

                for userId in userIdsToFetch {
                    group.enter()
                    self.db.collection("users").document(userId).getDocument { snap, _ in
                        if let data = snap?.data() {
                            userMap[userId] = (
                                name: data["username"] as? String ?? "...",
                                photo: data["photoURL"] as? String ?? ""
                            )
                        }
                        group.leave()
                    }
                }

                // พอดึงครบทุก user ค่อย update UI ครั้งเดียว
                group.notify(queue: .main) {
                    var finalChats = chatDict
                    for (roomId, chat) in finalChats {
                        if let userInfo = userMap[chat.otherUserId] {
                            finalChats[roomId]?.otherUsername = userInfo.name
                            if !userInfo.photo.isEmpty {
                                finalChats[roomId]?.otherUserPhotoURL = userInfo.photo
                            }
                        }
                    }
                    self.recentChats = finalChats.values.sorted { $0.timestamp > $1.timestamp }
                }
            }
    }
    
    private func refreshUsernames() {
        for (index, chat) in recentChats.enumerated() {
            db.collection("users").document(chat.otherUserId).getDocument { [weak self] snap, _ in
                guard let self = self, let data = snap?.data() else { return }
                let latestName = data["username"] as? String ?? chat.otherUsername
                let latestPhoto = data["photoURL"] as? String ?? chat.otherUserPhotoURL
                
                DispatchQueue.main.async {
                    if index < self.recentChats.count {
                        self.recentChats[index].otherUsername = latestName
                        self.recentChats[index].otherUserPhotoURL = latestPhoto
                    }
                }
            }
        }
    }
    
    func deleteChat(roomId: String) {
        db.collection("chats").whereField("roomId", isEqualTo: roomId).getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
        }
    }
}
