import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class UserManager: ObservableObject {
    
    @Published var username: String = ""
    @Published var photoURL: String = ""
    @Published var isAdmin: Bool = false
    @Published var isLoading: Bool = true
    
    func fetchUser() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // โหลด user ปกติ
        db.collection("users").document(uid).getDocument { snapshot, _ in
            if let data = snapshot?.data() {
                DispatchQueue.main.async {
                    self.username = data["username"] as? String ?? ""
                    self.photoURL = data["photoURL"] as? String ?? ""
                }
            }
        }
        
        // เช็ค admins collection แยก
        db.collection("admins").document(uid).getDocument { snapshot, _ in
            DispatchQueue.main.async {
                self.isAdmin   = snapshot?.exists ?? false
                self.isLoading = false
            }
        }
    }
}
