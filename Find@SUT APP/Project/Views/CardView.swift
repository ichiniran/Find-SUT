import SwiftUI
import Kingfisher
import FirebaseFirestore

struct CardView: View {
    
    @EnvironmentObject var bookmarkManager: BookmarkManager
    var item: Item
    @State private var fetchedUsername: String = ""
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 6) {
            
            // IMAGE + STATUS CHIP OVERLAY (แทน bookmark เดิม)
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    if !item.image.isEmpty, URL(string: item.image) != nil {
                        KFImage(URL(string: item.image))
                            .resizable()
                            .placeholder { ProgressView() }
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 150)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        ZStack {
                            Color(.systemGray5)
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("ไม่มีรูปภาพ")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .cornerRadius(8)
                    }
                    
                    // STATUS CHIP บนรูป (มุมขวาบน)
                    statusChip(for: item.status)
                        .padding(8)
                }
            }
            .frame(height: 150)
            
            // TITLE + BOOKMARK (บรรทัดเดียวกัน)
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button {
                    bookmarkManager.toggleBookmark(item: item)
                } label: {
                    Image(systemName: bookmarkManager.isBookmarked(item) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
            }
            .padding(.top, 8)
            // DESCRIPTION
            
            /*Text(item.description)
             .font(.system(size: 12))
             .lineLimit(1)
             .foregroundColor(.gray)*/
            //Spacer()
            // LOCATION
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                Text(item.location)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .foregroundColor(.white)
            .clipShape(Capsule())
            Spacer()
            // USER + DATE
            HStack {
                Text(fetchedUsername.isEmpty ? "..." : fetchedUsername)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.black)
                
                Spacer()
                
                Text(item.date)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
        }
        .padding(15)
        .frame(maxWidth: 200, alignment: .leading)
        .frame(height: 280)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 5)
        .onAppear {
            guard !item.userId.isEmpty else { return }
            Firestore.firestore().collection("users").document(item.userId).getDocument { snap, _ in
                if let data = snap?.data() {
                    fetchedUsername = data["username"] as? String ?? "Unknown"
                }
            }
        }
    }
    
    // MARK: - STATUS CHIP
    @ViewBuilder
    func statusChip(for status: String) -> some View {
        if status == "rejected" {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                Text("ถูกปิดกั้น")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
        } else {
            let isWaiting = status == "waiting"
            let isLostWaiting = item.type == "lost" && isWaiting
            let dotColor: Color = isLostWaiting ? .red : (isWaiting ? .orange : .green)
            let textColor: Color = isLostWaiting ? Color(hex: "#B91C1C") : (isWaiting ? .orange : .green)
            let label: String = {
                if item.type == "lost" {
                    return isWaiting ? "ยังตามหาของอยู่" : "ได้รับของคืนแล้ว"
                } else {
                    return isWaiting ? "รอเจ้าของมารับ" : "เจ้าของรับไปแล้ว"
                }
            }()
            HStack(spacing: 4) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
        }
    }
}
