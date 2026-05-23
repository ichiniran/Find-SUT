import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MyPostsView: View {
    @Environment(\.dismiss) var dismiss

    enum PostType { case found, lost }
    @State private var isLoading: Bool = true
    @State private var selectedType: PostType = .found
    @State private var items: [Item] = []
    @State private var username: String = ""
    @State private var photoURL: String? = nil
    @State private var profileImage: UIImage? = nil
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var filteredItems: [Item] {
        items.filter { $0.type == (selectedType == .found ? "found" : "lost") }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ─── HEADER ───
            ZStack() {
                Color.formBackground.ignoresSafeArea()
                
                VStack(spacing: 10) {
                    // TOP BAR
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").foregroundColor(.darkText)
                        }
                        Spacer()
                        Text("โพสต์ของฉัน").font(.headline).foregroundColor(.darkText)
                        Spacer()
                        Image(systemName: "chevron.left").opacity(0)
                    }
                    .padding(.horizontal, 20)
                    
                    // TAB
                    HStack {
                        tabButton(title: "พบของ", type: .found)
                        Spacer()
                        tabButton(title: "ของหาย", type: .lost)
                    }
                    .padding(.horizontal, 80).padding(.top, 20)
                    
                    // INDICATOR
                    GeometryReader { geo in
                        let width = geo.size.width / 2
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: 80, height: 4)
                            .offset(x: selectedType == .found ? width * 0.5 - 35 : width * 1.5 - 45)
                            .animation(.easeInOut(duration: 0.25), value: selectedType)
                    }
                    .frame(height: 5)
                }
                .padding(.top, 20)
            }
            .frame(height: 100)
            Divider()

            // ─── CONTENT ───
            if filteredItems.isEmpty {
                Spacer()
                Text("ยังไม่มีโพสต์").foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: DetailView(item: item)) {
                                CardView(item: item).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 12).padding(.top, 10)
                }
            }
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) 
        .onAppear {
            fetchMyPosts()
            loadUser()
        }
    }
   
    // ─── FETCH MY POSTS ───
    func fetchMyPosts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error { return }
                guard let documents = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    self.items = documents.map { doc in
                        let data = doc.data()
                        return Item(
                            id: doc.documentID, image: (data["images"] as? [String])?.first ?? "",
                            images: data["images"] as? [String] ?? [], title: data["category"] as? String ?? "ไม่มีชื่อ",
                            description: data["detail"] as? String ?? "", location: data["location"] as? String ?? "",
                            locationDetail: data["locationDetail"] as? String ?? "", latitude: data["latitude"] as? Double ?? 0,
                            longitude: data["longitude"] as? Double ?? 0, returnLocation: data["returnLocation"] as? String ?? "",
                            returnImage: data["returnImage"] as? String ?? "", username: data["username"] as? String ?? "",
                            userId: data["userId"] as? String ?? "", date: data["date"] as? String ?? "",
                            type: data["type"] as? String ?? "", status: data["status"] as? String ?? "waiting",
                            userPhotoURL: data["userPhotoURL"] as? String ?? ""
                        )
                    }
                }
            }
    }
    
    func loadUser() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, _ in
            DispatchQueue.main.async {
                if let data = snapshot?.data() {
                    self.username = data["username"] as? String ?? ""
                    self.photoURL = data["photoURL"] as? String
                }
            }
            if let urlString = snapshot?.data()?["photoURL"] as? String, let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    DispatchQueue.main.async {
                        if let data = data { self.profileImage = UIImage(data: data) }
                        self.isLoading = false
                    }
                }.resume()
            } else {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }
}

// ─── TAB BUTTON ───
extension MyPostsView {
    func tabButton(title: String, type: PostType) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(selectedType == type ? Color.loginTitle : Color.gray)
            .onTapGesture {
                withAnimation(.easeInOut) { selectedType = type }
            }
    }
}

#Preview { MyPostsView() }
