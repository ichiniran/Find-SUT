import SwiftUI

struct PostView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: 50)

                // Logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 42)

                Spacer()
                    .frame(height: 100)

                // Buttons
                VStack(spacing: 14) {
                    NavigationLink(destination: PostFormView(type: .found)) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#FFF0E0"))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(Color(hex: "#F97316"))
                                    .font(.system(size: 18))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("พบของ")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#5A4633"))
                                Text("แจ้งว่าพบของผู้อื่น")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#FBAA58"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#FBAA58"))
                        }
                        .padding(18)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
                    }

                    NavigationLink(destination: PostFormView(type: .lost)) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#FFF0E0"))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color(hex: "#F97316"))
                                    .font(.system(size: 18))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ของหาย")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#5A4633"))
                                Text("แจ้งว่าของตัวเองหาย")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#FBAA58"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#FBAA58"))
                        }
                        .padding(18)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
                    }

                    // ข้อความด้านล่างปุ่ม
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#F97316"))
                        
                        Text("กรุณาให้ข้อมูลที่ถูกต้องและครบถ้วนเพื่อช่วยให้การตามหาของรวดเร็วขึ้น")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#a0856a"))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#FFF3E0"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#FBAA58").opacity(0.4), lineWidth: 1)
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(Color(hex: "#FFFAF5").ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview { PostView() }
