import SwiftUI
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isMe: Bool
}

let mockMessages: [Message] = [
    Message(text: "สวัสดีค่ะ", isMe: true),
    Message(text: "เราเป็นเจ้าของบัตรนะคะ", isMe: true),
    Message(text: "ขอบคุณมากนะคะที่เก็บไว้ให้", isMe: true),
    Message(text: "ยินดีมากครับ 😊", isMe: false),
    Message(text: "สะดวกนัดรับตรงไหนครับ", isMe: false)
]
