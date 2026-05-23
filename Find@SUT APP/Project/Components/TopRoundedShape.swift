import SwiftUI

struct TopRightCornerShape: Shape {
    
    var radius: CGFloat = 80
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        // เริ่มจากมุมซ้ายบน (ไม่โค้ง)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // เส้นบนไปก่อนถึงมุมขวา
        path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
        
        // โค้งมุมขวาบน
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: radius),
            control: CGPoint(x: rect.width, y: 0)
        )
        
        // ด้านขวา
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        
        // ด้านล่าง
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        
        // ปิด path
        path.closeSubpath()
        
        return path
    }
}
