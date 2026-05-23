import SwiftUI

struct SavedView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bookmarkManager: BookmarkManager
    
    enum PostType { case found, lost }
    @State private var selectedType: PostType = .found
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // filter bookmarks
    var filteredItems: [BookmarkItem] {
        bookmarkManager.bookmarks.filter {
            $0.type == (selectedType == .found ? "found" : "lost")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ─── HEADER ───
            ZStack(alignment: .bottom) {
                Color.formBackground.ignoresSafeArea()
                
                VStack(spacing: 10) {
                    // TOP BAR
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").foregroundColor(.darkText)
                        }
                        Spacer()
                        Text("บันทึกของฉัน").font(.headline).foregroundColor(.darkText)
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
                    .padding(.horizontal, 80)
                    .padding(.top, 20)
                    
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
                Text("ยังไม่มีรายการที่บันทึก").foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredItems, id: \.id) { bookmark in
                            let item = convertToItem(bookmark: bookmark)
                            NavigationLink(destination: DetailView(item: item)) {
                                CardView(item: item).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
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
            bookmarkManager.fetchBookmarks()
        }
    }
}

// ─── TAB BUTTON ───
extension SavedView {
    func tabButton(title: String, type: PostType) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(selectedType == type ? Color.loginTitle : Color.gray)
            .onTapGesture {
                withAnimation(.easeInOut) { selectedType = type }
            }
    }
}

// ─── CONVERT Bookmark → Item ───
extension SavedView {
    func convertToItem(bookmark: BookmarkItem) -> Item {
        return Item(
            id: bookmark.id, image: bookmark.image, images: bookmark.image.isEmpty ? [] : [bookmark.image],
            title: bookmark.title, description: bookmark.description, location: bookmark.location,
            locationDetail: "", latitude: 0, longitude: 0, returnLocation: "", returnImage: "",
            username: bookmark.username, userId: bookmark.userId, date: formatDate(bookmark.date),
            type: bookmark.type, status: bookmark.status, userPhotoURL: bookmark.userPhotoURL
        )
    }
}

// ─── FORMAT DATE ───
extension SavedView {
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    SavedView().environmentObject(BookmarkManager())
}
