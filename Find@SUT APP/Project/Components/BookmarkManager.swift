import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

class BookmarkManager: ObservableObject {
    
    @Published var bookmarkedIds: Set<String> = []
    @Published var bookmarks: [BookmarkItem] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() {
        startListening()
    }
    func startListening() {
           guard let userId = Auth.auth().currentUser?.uid else { return }
           
           listener?.remove()  // ล้าง listener เก่าก่อน
           listener = db.collection("bookmarks")
               .document(userId)
               .collection("userBookmarks")
               .addSnapshotListener { [weak self] snapshot, _ in
                   guard let self, let documents = snapshot?.documents else { return }
                   let ids = Set(documents.map { $0.documentID })
                   DispatchQueue.main.async {
                       self.bookmarkedIds = ids
                   }
               }
       }
    // โหลด bookmark
    func fetchBookmarks() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("bookmarks")
            .document(userId)
            .collection("userBookmarks")
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                
                guard let documents = snapshot?.documents else { return }
                
                let group = DispatchGroup()
                var validItems: [BookmarkItem] = []
                
                for doc in documents {
                    let data = doc.data()
                    let postId = doc.documentID
                    
                    group.enter()
                    // เช็คว่าโพสต์ยังมีอยู่มั้ย
                    self.db.collection("posts").document(postId).getDocument { postSnap, _ in
                        if postSnap?.exists == true {
                            let postData = postSnap?.data()
                            let item = BookmarkItem(
                                id: postId,
                                title: data["title"] as? String ?? "",
                                description: data["description"] as? String ?? "",
                                image: data["image"] as? String ?? "",
                                username: data["username"] as? String ?? "",
                                userPhotoURL: data["userPhotoURL"] as? String ?? "",
                                type: data["type"] as? String ?? "",
                                status: postData?["status"] as? String ?? "waiting",                                date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
                                userId: data["userId"] as? String ?? "",
                                location: data["location"] as? String ?? ""
                            )
                            validItems.append(item)
                        } else {
                            // โพสต์ถูกลบไปแล้ว ลบ bookmark ออกด้วย
                            self.db.collection("bookmarks")
                                .document(userId)
                                .collection("userBookmarks")
                                .document(postId)
                                .delete()
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.bookmarks = validItems
                    self.bookmarkedIds = Set(validItems.map { $0.id })
                }
            }
    }

    // toggle save / unsave
    func toggleBookmark(item: Item) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let ref = db.collection("bookmarks")
            .document(userId)
            .collection("userBookmarks")
            .document(item.id)
        
        if bookmarkedIds.contains(item.id) {
            // ลบจาก Firebase
            ref.delete()
            
            //  ลบใน local ทันที (ทำให้ UI หายเลย)
            bookmarkedIds.remove(item.id)
            bookmarks.removeAll { $0.id == item.id }
        } else {
            //  บันทึก
            let data: [String: Any] = [
                "itemId": item.id,
                "title": item.title,
                "description": item.description,
                "image": item.image,
                "username": item.username,
                "userPhotoURL": item.userPhotoURL,
                "type": item.type,
                "status": item.status,
                "date": Timestamp(date: Date()),
                "userId": item.userId,
                "location": item.location
            ]
            
            ref.setData(data)
            bookmarkedIds.insert(item.id)
        }
    }
    
    func isBookmarked(_ item: Item) -> Bool {
        bookmarkedIds.contains(item.id)
    }
}
