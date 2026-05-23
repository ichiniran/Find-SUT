import Foundation

enum ItemType {
    case found   // พบของ
    case lost    // ของหาย
}

struct LostItem: Identifiable {
    let id = UUID()
    
    let title: String
    let description: String
    
    let image: String              // 👈 URL
    let returnImages: [String]     // 👈 URL ทั้งหมด
    
    let location: String
    let receiveLocation: String
    
    let username: String
    let date: String
    let type: ItemType
}
