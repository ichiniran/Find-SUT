import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct ChatMessage: Identifiable {
    var id: String
    var roomId: String
    var senderId: String
    var receiverId: String
    var text: String
    var timestamp: Date
    var isRead: Bool
    var sharedItemData: [String: Any]?
    var imageURL: String?
    
    var isMe: Bool {
        return senderId == Auth.auth().currentUser?.uid
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    func fetchMessages(with receiverId: String) {
        listener?.remove()
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let roomId = [currentUserID, receiverId].sorted().joined(separator: "_")
        
        listener = db.collection("chats").whereField("roomId", isEqualTo: roomId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                var fetchedMessages = documents.compactMap { doc -> ChatMessage? in
                    let data = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        roomId: data["roomId"] as? String ?? "",
                        senderId: data["senderId"] as? String ?? "",
                        receiverId: data["receiverId"] as? String ?? "",
                        text: data["text"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead: data["isRead"] as? Bool ?? false,
                        sharedItemData: data["sharedItem"] as? [String: Any],
                        imageURL: data["imageURL"] as? String
                    )
                }
                
                fetchedMessages.sort { $0.timestamp < $1.timestamp }
                self.messages = fetchedMessages
                self.markAsRead(roomId: roomId)
            }
    }
    private func saveMessage(roomId: String, currentUserID: String, receiverId: String,
                             myName: String, myPhotoURL: String, receiverName: String,
                             receiverPhotoURL: String, text: String,
                             itemToShare: Item?, imageURL: String?) {
        var data: [String: Any] = [
            "roomId": roomId,
            "participants": [currentUserID, receiverId],
            "senderId": currentUserID,
            "receiverId": receiverId,
            "senderName": myName,
            "senderPhotoURL": myPhotoURL,
            "receiverName": receiverName,
            "receiverPhotoURL": receiverPhotoURL,
            "text": text,
            "timestamp": Timestamp(date: Date()),
            "isRead": false
        ]

        if let imageURL = imageURL {
            data["imageURL"] = imageURL
        }

        if let item = itemToShare {
            data["sharedItem"] = [
                "id": item.id,
                "title": item.title,
                "image": item.image,
                "images": item.images,
                "description": item.description,
                "location": item.location,
                "locationDetail": item.locationDetail,
                "returnLocation": item.returnLocation,
                "returnImage": item.returnImage,
                "username": item.username,
                "userId": item.userId,
                "date": item.date,
                "type": item.type,
                "status": "waiting",
                "userPhotoURL": item.userPhotoURL
            ]
        }

        db.collection("chats").addDocument(data: data)
    }
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func sendMessage(text: String, receiverId: String, receiverName: String,
                     receiverPhotoURL: String = "", itemToShare: Item? = nil,
                     image: UIImage? = nil) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let roomId = [currentUserID, receiverId].sorted().joined(separator: "_")
        let myName = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "User"
        let myPhotoURL = Auth.auth().currentUser?.photoURL?.absoluteString ?? ""

        if let image = image {
            // มีรูป → upload Cloudinary ก่อน
            Task {
                if let imageURL = await uploadToCloudinary(image: image) {
                    saveMessage(roomId: roomId, currentUserID: currentUserID,
                                receiverId: receiverId, myName: myName, myPhotoURL: myPhotoURL,
                                receiverName: receiverName, receiverPhotoURL: receiverPhotoURL,
                                text: text, itemToShare: itemToShare, imageURL: imageURL)
                }
            }
        } else {
            // ไม่มีรูป → save ทันที
            saveMessage(roomId: roomId, currentUserID: currentUserID,
                        receiverId: receiverId, myName: myName, myPhotoURL: myPhotoURL,
                        receiverName: receiverName, receiverPhotoURL: receiverPhotoURL,
                        text: text, itemToShare: itemToShare, imageURL: nil)
        }
    }

    // MARK: - Cloudinary Upload (เหมือน PostFormView)
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
        append("findsut\r\n")          // ← preset เดิมของโปรเจกต์
        append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (resData, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: resData) as? [String: Any]
            return json?["secure_url"] as? String
        } catch {
            print("Cloudinary upload error:", error)
            return nil
        }
    }
    
    private func markAsRead(roomId: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        db.collection("chats")
            .whereField("roomId", isEqualTo: roomId)
            .whereField("receiverId", isEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.updateData(["isRead": true]) }
            }
    }
}
