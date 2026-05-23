import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    
    @Binding var isLogin: Bool
    @EnvironmentObject var userManager: UserManager
    @State private var showLogoutAlert = false
    
    var body: some View {
        VStack(spacing: 2) {
            
            // HEADER
            ZStack {
                Color.formBackground
                    .ignoresSafeArea(edges: .top)
                
                HStack(spacing: 15) {
                    
                    // PROFILE IMAGE
                    ZStack {
                        if let url = URL(string: userManager.photoURL),
                           !userManager.photoURL.isEmpty {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 55, height: 55)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 55, height: 55)
                            
                            Text(
                                userManager.username.isEmpty
                                ? "U"
                                : String(userManager.username.prefix(1)).uppercased()
                            )
                            .foregroundColor(.darkText)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userManager.username.isEmpty ? "..." : userManager.username)
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .foregroundColor(.loginTitle)
                        
                        NavigationLink(destination: EditProfileView()) {
                            HStack {
                                Text("แก้ไขโปรไฟล์")
                                    .font(.system(size: 14))
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                            }
                        }
                        .foregroundColor(.loginTitle)
                    }
                    Spacer()
                }
                .padding(.leading, 40)
            }
            .frame(height: 120)
            
            // MENU
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    AccountView()
                } label: {
                    menuRow(title: "จัดการบัญชี")
                }
                Divider()
                NavigationLink {
                    SavedView()
                } label: {
                    menuRow(title: "บันทึกของฉัน")
                }
                Divider()
                NavigationLink {
                    MyPostsView()
                } label: {
                    menuRow(title: "โพสต์ของฉัน")
                }
                Divider()
                NavigationLink {
                    ClaimedPostsView()
                } label: {
                    menuRow(title: "รายการรับของของฉัน")
                }
            }
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            .padding(.horizontal, 16)
            
            // CONTACT ADMIN
            NavigationLink {
                ChatDetailView(
                    receiverId: AdminConstants.uid,
                    receiverName: AdminConstants.name,
                    receiverPhotoURL: "",
                    itemToShare: nil
                )
            } label: {
                HStack {
                    Image(systemName: "message.fill")
                    Text("ติดต่อแอดมิน")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                .padding(.top, 10)
                .foregroundColor(Color.gray)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }
            
            // LOGOUT
            Button {
                showLogoutAlert = true
            } label: {
                Text("ออกจากระบบ")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .padding()
                    .foregroundColor(.red)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }
            .alert("ออกจากระบบ", isPresented: $showLogoutAlert) {
                Button("ยกเลิก", role: .cancel) {}
                Button("ออกจากระบบ", role: .destructive) {
                    do {
                        try Auth.auth().signOut()
                        isLogin = false
                    } catch {
                        print("Logout error:", error.localizedDescription)
                    }
                }
            } message: {
                Text("คุณต้องการออกจากระบบใช่ไหม?")
            }
            
            Spacer()
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            userManager.fetchUser()
        }
    }
}

// MARK: - Menu Row
extension ProfileView {
    func menuRow(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.loginTitle)
                .font(.system(size: 14))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.loginTitle)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.darkText.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

#Preview {
    ProfileView(isLogin: .constant(true))
}
