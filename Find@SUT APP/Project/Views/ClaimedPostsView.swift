import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ClaimedPostsView: View {

    @Environment(\.dismiss) var dismiss
    @State private var posts: [Item] = []
    @State private var isLoading = true

    let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 2) {

            // HEADER (เหมือน AccountView)
            ZStack {
                Color.formBackground
                    .ignoresSafeArea(edges: .top)

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color.darkText)
                    }

                    Spacer()

                    Text("รายการรับของของฉัน")
                        .font(.headline)
                        .foregroundColor(Color.darkText)

                    Spacer()

                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 50)
            
            Divider()
            // CONTENT
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.orange)
                Spacer()

            } else if posts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                   /* Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    */
                    Text("ยังไม่มีรายการรับของ")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#a0856a"))
                }
                Spacer()

            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(posts) { item in
                            NavigationLink(destination: DetailView(item: item)) {
                                CardView(item: item)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
            }
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)  // ซ่อน nav bar
        .toolbar(.hidden, for: .tabBar)         // ซ่อน tab bar
        .onAppear { fetchClaimedPosts() }
    }

    // MARK: - FETCH
    func fetchClaimedPosts() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        Firestore.firestore().collection("posts")
            .whereField("claimedBy", isEqualTo: uid)
            .whereField("status", isEqualTo: "claimed")
            .whereField("type", isEqualTo: "found")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    print("Error:", error.localizedDescription)
                    isLoading = false
                    return
                }

                self.posts = snapshot?.documents.map { doc in
                    let data = doc.data()
                    return Item(
                        id: doc.documentID,
                        image: (data["images"] as? [String])?.first ?? "",
                        images: data["images"] as? [String] ?? [],
                        title: data["category"] as? String ?? "ไม่มีชื่อ",
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
                        type: data["type"] as? String ?? "",
                        status: data["status"] as? String ?? "claimed",
                        userPhotoURL: data["userPhotoURL"] as? String ?? ""
                    )
                } ?? []

                isLoading = false
            }
    }
}
