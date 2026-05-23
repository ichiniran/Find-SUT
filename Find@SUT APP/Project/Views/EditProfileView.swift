import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

struct EditProfileView: View {
    
    @Environment(\.dismiss) var dismiss

    // MARK: STATE
    @State private var username: String = ""
    @State private var photo: UIImage? = nil
    @State private var photoURL: String? = nil
    
    @State private var showPicker = false
    @State private var isSaving = false
    
    let db = Firestore.firestore()
    
    var body: some View {
        
        ZStack {
            
            // BACKGROUND
            Color.formBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // ─── HEADER ───
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#6B4D34"))
                    }
                    
                    Spacer()
                    
                    Text("แก้ไขโปรไฟล์")
                        .font(.headline)
                        .foregroundColor(Color.darkText)
                    
                    Spacer()
                    
    
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .frame(height: 50)

            // ─── PROFILE ───
                // ─── PROFILE ───
                VStack(spacing: 12) {
                    
                    ZStack {
                        
                        if let photo = photo {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        
                        } else if let url = photoURL {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                        
                        } else {
                            Circle()
                                .fill(Color(hex: "#f3e3d3"))
                                .frame(width: 110, height: 110)
                            
                            Text(username.isEmpty ? "U" : String(username.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color(hex: "#6E4D31"))
                        }
                        
                        // camera icon
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                            .offset(x: 30, y: 30)
                    }
                    .onTapGesture {
                        showPicker = true
                    }
                    
                    Text("แตะเพื่อเปลี่ยนรูปภาพ")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    //  ปุ่มลบรูป แสดงเฉพาะเมื่อมีรูป
                    if photo != nil || photoURL != nil {
                        Button {
                            removePhoto()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("ลบรูปโปรไฟล์")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            //.padding(.horizontal, 12)
                            //.padding(.vertical, 6)
                            //.background(Color.red.opacity(0.08))
                            //.cornerRadius(20)
                        }
                    }
                }
                .padding(.top, 20)
                
                // ─── FORM ───
                VStack(spacing: 16) {
                    
                    HStack {
                        Text("ชื่อผู้ใช้")
                            .foregroundColor(Color(hex: "#6B4D34"))
                        
                        Spacer()
                        
                        TextField("ชื่อผู้ใช้", text: $username)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // SAVE BUTTON
                    Button {
                        saveProfile()
                    } label: {
                        Text(isSaving ? "กำลังบันทึก..." : "บันทึก")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#F97316"))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(isSaving)
                }
                .padding()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            loadUser()
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(selectedImage: $photo)
        }
    }
}
extension EditProfileView {
    
    func loadUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(uid).getDocument { snapshot, error in
            
            if let data = snapshot?.data() {
                self.username = data["username"] as? String ?? ""
                self.photoURL = data["photoURL"] as? String
            }
        }
    }
    
    func removePhoto() {
        photo = nil
        photoURL = nil
        
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("users").document(user.uid).updateData([
            "photoURL": FieldValue.delete()
        ])
    }
    
    func saveProfile() {
        guard let user = Auth.auth().currentUser else { return }
        isSaving = true
        
        Task {
            var newPhotoURL = photoURL
            
            if let photo = photo {
                newPhotoURL = await uploadToCloudinary(image: photo)
            }
            
            // update Auth
            let change = user.createProfileChangeRequest()
            change.displayName = username
            change.photoURL = newPhotoURL != nil ? URL(string: newPhotoURL!) : nil
            try? await change.commitChanges()
            
            // update users collection
            var data: [String: Any] = ["username": username]
            
            if let url = newPhotoURL, !url.isEmpty {
                data["photoURL"] = url
            } else {
                data["photoURL"] = FieldValue.delete()
            }
            
            try? await db.collection("users").document(user.uid).updateData(data)
            
           
            let posts = try? await db.collection("posts")
                .whereField("userId", isEqualTo: user.uid)
                .getDocuments()
            
            for doc in posts?.documents ?? [] {
                let updateData: [String: Any] = [
                    "userPhotoURL": newPhotoURL ?? "",
                    "username": username
                ]
                try? await db.collection("posts").document(doc.documentID).updateData(updateData)
            }
            
            isSaving = false
            dismiss()
        }
    }
    func uploadToCloudinary(image: UIImage) async -> String? {
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return nil }
        
        let url = URL(string: "https://api.cloudinary.com/v1_1/dy9lc24op/image/upload")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("findsut".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["secure_url"] as? String
        } catch {
            print("Upload error:", error.localizedDescription)
            return nil
        }
    }
}
#Preview {
    EditProfileView()
}
