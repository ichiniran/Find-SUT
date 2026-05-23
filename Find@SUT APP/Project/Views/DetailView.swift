import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

enum PostStatus { case waiting, claimed }

// MARK: - Static Map (read-only pin, no drag)
struct StaticMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isUserInteractionEnabled = false

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            view.markerTintColor = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
            return view
        }
    }
}

// MARK: - DetailView
struct DetailView: View {

    let item: Item
    @Binding var hideTabBar: Bool
    @State private var showDuplicateAlert = false
    @Environment(\.dismiss) var dismiss
    @State private var status: PostStatus = .waiting
    @State private var imgIdx: Int = 0
    @State private var showDeleteAlert = false
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @State private var showReturnImage = false
    @State private var showConfirmAlert = false
    @State private var showEditView = false
    @State private var showReportSheet = false
    @State private var displayItem: Item
    @State private var showNoPhoneAlert = false
    @State private var navigateToAccount = false
    @State private var navigateToAdminChat = false
    // Map
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 14.8775, longitude: 102.0170),
        latitudinalMeters: 500, longitudinalMeters: 500
    )
    @State private var showFullMap = false

    // ── Claimed info (เพิ่มใหม่) ──
    @State private var claimedBy: String = ""        // uid ของผู้รับ
    @State private var claimedByName: String = ""    // ชื่อผู้รับ (real-time)
    @State private var claimerListener: ListenerRegistration?  // listener ชื่อผู้รับ
    @State private var postListener: ListenerRegistration?     // listener โพสต์

    init(item: Item, hideTabBar: Binding<Bool> = .constant(false)) {
        self.item = item
        self._displayItem = State(initialValue: item)
        self._hideTabBar = hideTabBar
    }

    var isFound: Bool { item.type == "found" }
    var currentUID: String? { Auth.auth().currentUser?.uid }
    var isOwner: Bool { currentUID == item.userId }

    var hasLocation: Bool {
        displayItem.latitude != 0 && displayItem.longitude != 0
    }

    var itemCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: displayItem.latitude, longitude: displayItem.longitude)
    }

    var shouldShowBottomBar: Bool {
        if isFound { return true }   // found: แสดงเสมอ (มี claimedBox)
        return true
    }

    // MARK: - Body
    var body: some View {
        // นำ ZStack มาครอบเนื้อหาทั้งหมด เพื่อให้คำสั่งซ่อน TabBar คลุมได้ทั้งหน้าจอ
        ZStack {
            NavigationLink(destination: AccountView(), isActive: $navigateToAccount) {
                EmptyView()
            }
            NavigationLink(
                destination: ChatDetailView(
                    receiverId: AdminConstants.uid,
                    receiverName: AdminConstants.name,
                    receiverPhotoURL: "",
                    itemToShare: displayItem
                ),
                isActive: $navigateToAdminChat
            ) {
                EmptyView()
            }
            
            VStack(spacing: 0) {
                topNav
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        imageGallery
                        contentCard
                    }
                }
                .frame(maxHeight: .infinity)
                bottomBar
            }
            .background(Color.white)
            .overlay { if showReturnImage { returnImageOverlay } }
        }
    // ย้ายคำสั่งซ่อนมาไว้หลัง ZStack
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        
        // .onAppear, .onDisappear และ .sheet อื่นๆ ต่อจากนี้ไว้เหมือนเดิม...
        .onAppear {
            $hideTabBar.wrappedValue = true
            startPostListener()       // real-time listener แทน fetchLatestItem
            bookmarkManager.fetchBookmarks()
        }
        .onDisappear {
            $hideTabBar.wrappedValue = false
            postListener?.remove()
            claimerListener?.remove()
        }
        .sheet(isPresented: $showEditView, onDismiss: { startPostListener() }) {
            PostFormView(
                type: item.type == "found" ? .found : .lost,
                existingItem: displayItem
            )
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(item: displayItem)
        }
        .sheet(isPresented: $showFullMap) {
            fullMapSheet
        }
        .alert(isFound ? "ยืนยันการรับของ" : "ยืนยันการได้รับของ",
               isPresented: $showConfirmAlert) {
            Button("ยกเลิก", role: .cancel) {}
            Button("ยืนยัน") { updatePostStatus() }
        } message: {
            Text(isFound ? "ยืนยันว่าเจ้าของได้มารับของแล้วใช่ไหม?" : "ยืนยันว่าคุณได้รับของคืนแล้วใช่ไหม?")
        }
        .alert("ลบโพสต์", isPresented: $showDeleteAlert) {
            Button("ยกเลิก", role: .cancel) {}
            Button("ลบ", role: .destructive) { deletePost() }
        } message: { Text("คุณต้องการลบโพสต์นี้หรือไม่?")
        }
        
    }
    

    // MARK: - Top Nav
    var topNav: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                    .foregroundColor(.primary)
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: "#f8e8dc")).frame(width: 38, height: 38)
                    if let url = URL(string: displayItem.userPhotoURL), !displayItem.userPhotoURL.isEmpty {
                        AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                            placeholder: { ProgressView() }
                            .frame(width: 38, height: 38).clipShape(Circle())
                    } else {
                        Text(String(displayItem.username.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#6E4D31"))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayItem.username.isEmpty ? "-" : displayItem.username)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.black)
                    Text("โพสต์เมื่อ \(displayItem.date)")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
            }

            Spacer()

            Menu {
                if isOwner {
                    Button("แก้ไข") { showEditView = true }
                    Button("ลบโพสต์", role: .destructive) { showDeleteAlert = true }
                    Button("ติดต่อแอดมิน") {
                        navigateToAdminChat = true
                    }
                } else {
                    Button("รายงาน") { showReportSheet = true }
                }
                
                //Divider()
                
                
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.gray).font(.system(size: 18))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Image Gallery
    var imageGallery: some View {
        ZStack(alignment: .topTrailing) {
            if !displayItem.images.isEmpty {
                TabView(selection: $imgIdx) {
                    ForEach(displayItem.images.indices, id: \.self) { idx in
                        AsyncImage(url: URL(string: displayItem.images[idx])) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Color.gray.opacity(0.15)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 300).clipped().tag(idx)
                    }
                }
                .frame(height: 300)
                .tabViewStyle(.page(indexDisplayMode: .never))

                if displayItem.images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(displayItem.images.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == imgIdx ? Color.white : Color.white.opacity(0.4))
                                .frame(width: i == imgIdx ? 18 : 6, height: 6)
                        }
                    }
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 300, alignment: .bottom)
                }
            } else {
                ZStack {
                    Color(.systemGray5)
                    VStack(spacing: 8) {
                        Image(systemName: "photo").font(.system(size: 48)).foregroundColor(.gray.opacity(0.4))
                        Text("ไม่มีรูปภาพ").font(.system(size: 13)).foregroundColor(.gray.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 300)
            }

            statusChip
                .padding(14)
        }
    }

    // MARK: - Content Card
    var contentCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Title + Bookmark ──
            HStack(alignment: .top, spacing: 14) {
                Text(displayItem.title.isEmpty ? "ไม่ระบุชื่อ" : displayItem.title)
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button { bookmarkManager.toggleBookmark(item: displayItem) } label: {
                    Image(systemName: bookmarkManager.isBookmarked(displayItem) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(bookmarkManager.isBookmarked(displayItem) ? .orange : .gray)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            // ── Info rows ──
            VStack(spacing: 20) {
                infoRow(icon: "doc.text", label: "รายละเอียด", value: displayItem.description)
                infoRow(icon: "calendar", label: isFound ? "วันที่พบ" : "วันที่หาย", value: displayItem.date)
                infoRow(icon: "mappin.and.ellipse", label: isFound ? "สถานที่พบ" : "สถานที่หาย", value: displayItem.location)

                if !displayItem.locationDetail.isEmpty {
                    infoRow(icon: "text.alignleft", label: "รายละเอียดเพิ่มเติม", value: displayItem.locationDetail)
                }

                if hasLocation { mapSection }

                if isFound {
                    if !displayItem.returnLocation.isEmpty {
                        infoRow(icon: "mappin", label: "สถานที่คืนของ", value: displayItem.returnLocation)
                    }
                    if !displayItem.returnImage.isEmpty { returnImageRow }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .background(Color.white)
        .padding(.top, 8)
    }

    // MARK: - Map Section
    var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#F97316"))
                Text("ตำแหน่งบนแผนที่")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#5A4633"))
                Spacer()
                Button { showFullMap = true } label: {
                    HStack(spacing: 4) {
                        Text("ขยาย").font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "#F97316"))
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11)).foregroundColor(Color(hex: "#F97316"))
                    }
                }
            }

            ZStack(alignment: .bottomTrailing) {
                StaticMapView(coordinate: itemCoordinate)
                    .frame(height: 180).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))

                Button { openInMaps() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill").font(.system(size: 11))
                        Text("เปิดใน Maps").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "#F97316")).cornerRadius(20)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .padding(10)
            }

            if !displayItem.location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 13)).foregroundColor(Color(hex: "#F97316"))
                    Text(displayItem.location).font(.system(size: 13)).foregroundColor(Color(hex: "#777777")).lineLimit(2)
                }
            }
        }
    }

    // MARK: - Full Map Sheet
    var fullMapSheet: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: itemCoordinate, latitudinalMeters: 500, longitudinalMeters: 500
                )), annotationItems: [displayItem]) { _ in
                    MapMarker(coordinate: itemCoordinate, tint: .orange)
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    Button { openInMaps() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                            Text("เปิดใน Apple Maps").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color(hex: "#F97316")).cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(displayItem.location.isEmpty ? "ตำแหน่งสถานที่" : displayItem.location)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ปิด") { showFullMap = false }.foregroundColor(Color(hex: "#F97316"))
                }
            }
        }
    }

    // MARK: - Return Image Row
    var returnImageRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "photo").font(.system(size: 20)).foregroundColor(.orange)
                .frame(width: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("รูปจุดรับคืน").font(.system(size: 12)).foregroundColor(.gray)
                Button { showReturnImage = true } label: {
                    AsyncImage(url: URL(string: displayItem.returnImage)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill().frame(width: 120, height: 120).cornerRadius(10).clipped()
                        default:
                            Color.gray.opacity(0.15).frame(width: 120, height: 120).cornerRadius(10)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Return Image Overlay
    var returnImageOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture { showReturnImage = false }
            AsyncImage(url: URL(string: displayItem.returnImage)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit().padding(20)
                default: ProgressView()
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Button { showReturnImage = false } label: {
                        Image(systemName: "xmark").font(.system(size: 20)).foregroundColor(.white).padding(16)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Bottom Bar
    var bottomBar: some View {
        VStack(spacing: 10) {
            if isFound {
                if status == .claimed && !claimedBy.isEmpty {
                    // กล่องเขียว: รับโดย + ติดต่อผู้รับ
                    claimedBox

                    // ติดต่อเจ้าของโพสต์ (แสดงเฉพาะคนที่ไม่ใช่เจ้าของ)
                    if !isOwner {
                        NavigationLink {
                            DeferView {
                                ChatDetailView(
                                    receiverId: item.userId,
                                    receiverName: displayItem.username,
                                    receiverPhotoURL: displayItem.userPhotoURL,
                                    itemToShare: displayItem
                                )
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 16))
                                Text("ติดต่อเจ้าของโพสต์").font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                    }

                    // ติดต่อแอดมิน (ทุกคนเห็น)
                    NavigationLink {
                        DeferView {
                            ChatDetailView(
                                receiverId: AdminConstants.uid,
                                receiverName: AdminConstants.name,
                                receiverPhotoURL: "",
                                itemToShare: displayItem
                            )
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill").font(.system(size: 16))
                            Text("ติดต่อแอดมิน").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#595b5a"))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.darkText, lineWidth: 1))
                        .cornerRadius(10)
                    }
                }

                if !isOwner && status == .waiting {
                    NavigationLink {
                        DeferView {
                            ChatDetailView(
                                receiverId: item.userId,
                                receiverName: displayItem.username,
                                receiverPhotoURL: displayItem.userPhotoURL,
                                itemToShare: displayItem
                            )
                        }
                    } label: {
                        Label("ติดต่อเจ้าของโพสต์", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.orange).foregroundColor(.white).cornerRadius(14)
                    }

                    Button {
                        guard isFound else { showConfirmAlert = true; return }
                        checkPhoneBeforeClaim()
                    } label: {
                        Label("ฉันเป็นเจ้าของและมารับแล้ว", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(hex: "#f0fdf4"))
                            .foregroundColor(Color(hex: "#16a34a")).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#bbf7d0"), lineWidth: 1.5))
                    }
                    .alert("ยังไม่มีเบอร์โทร", isPresented: $showNoPhoneAlert) {
                        Button("ยกเลิก", role: .cancel) {}
                        Button("ไปตั้งค่า") { navigateToAccount = true }
                    } message: {
                        Text("กรุณาเพิ่มเบอร์โทรในหน้าจัดการบัญชีก่อนรับของ")
                    }
                }
            } else {
                // ── lost post ──
                if !isOwner {
                    NavigationLink {
                        DeferView {
                            ChatDetailView(
                                receiverId: item.userId,
                                receiverName: displayItem.username,
                                receiverPhotoURL: displayItem.userPhotoURL,
                                itemToShare: displayItem
                            )
                        }
                    } label: {
                        Label("ติดต่อเจ้าของ", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.orange).foregroundColor(.white).cornerRadius(14)
                    }
                }
                if isOwner {
                    if status == .waiting {
                        Button { showConfirmAlert = true } label: {
                            Label("ฉันได้รับของแล้ว", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color(hex: "#f0fdf4"))
                                .foregroundColor(Color(hex: "#16a34a")).cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#bbf7d0"), lineWidth: 1.5))
                        }
                    } else {
                        claimedButton(text: "ได้รับของคืนแล้ว")
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.white)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - Claimed Box (เทียบเท่า claimedBox ใน React Native)
    var claimedBox: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#16a34a"))
                    .font(.system(size: 18))
                if currentUID == claimedBy {
                    Text("รับโดยฉัน")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#16a34a"))
                } else {
                    (Text("รับโดย ") + Text(claimedByName).bold())
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#16a34a"))
                }
                Spacer()
            }

            if currentUID != claimedBy {
                NavigationLink {
                    DeferView {
                        ChatDetailView(
                            receiverId: claimedBy,
                            receiverName: claimedByName,
                            receiverPhotoURL: "",
                            itemToShare: displayItem
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle").font(.system(size: 16))
                        Text("ติดต่อผู้รับ").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#16a34a"))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#86efac"), lineWidth: 1))
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#f0fdf4"))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#bbf7d0"), lineWidth: 1))
        .cornerRadius(14)
    }

    // MARK: - Status Chip
    @ViewBuilder
    var statusChip: some View {
        if status == .claimed {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#16a34a"))
                Text(isFound ? "เจ้าของมารับแล้ว" : "ได้รับของคืนแล้ว").foregroundColor(Color(hex: "#16a34a"))
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "#f0fdf4")).cornerRadius(20)
        } else if !isFound {
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 6, height: 6)
                Text("ยังตามหาของอยู่").foregroundColor(Color(hex: "#B91C1C"))
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "#FEF2F2")).cornerRadius(20)
        } else {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#E65100")).frame(width: 6, height: 6)
                Text("รอเจ้าของมารับ").foregroundColor(Color(hex: "#E65100"))
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "#FFF3E0")).cornerRadius(20)
        }
    }

    // MARK: - Helpers
    func claimedButton(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#16a34a"))
            Text(text).foregroundColor(Color(hex: "#16a34a"))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color(hex: "#f0fdf4")).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#bbf7d0"), lineWidth: 1.5))
    }

    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if !icon.isEmpty {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(.orange)
                    .frame(width: 20, height: 20, alignment: .center).padding(.top, 2)
            } else {
                Color.clear.frame(width: 20, height: 20).padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 12)).foregroundColor(.gray)
                Text(value.isEmpty ? "-" : value).font(.system(size: 15, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func openInMaps() {
        let placemark = MKPlacemark(coordinate: itemCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = displayItem.location.isEmpty ? "ตำแหน่งสถานที่" : displayItem.location
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Contact Admin
    func handleContactAdmin() {
        navigateToAdminChat = true
    }

    // MARK: - Firestore (real-time listener แทน getDocument)
    func startPostListener() {
        postListener?.remove()
        postListener = Firestore.firestore().collection("posts").document(item.id)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }
                let userId = data["userId"] as? String ?? ""
                let newStatus = data["status"] as? String ?? "waiting"
                let newClaimedBy = data["claimedBy"] as? String ?? ""

                // อัปเดต status และ claimedBy
                DispatchQueue.main.async {
                    self.status = newStatus == "claimed" ? .claimed : .waiting
                    self.claimedBy = newClaimedBy
                }

                // ถ้ามี claimedBy ให้ฟังชื่อผู้รับ real-time
                if !newClaimedBy.isEmpty {
                    startClaimerListener(uid: newClaimedBy)
                }

                // ดึงข้อมูล user ของเจ้าของโพสต์
                Firestore.firestore().collection("users").document(userId).getDocument { userSnap, _ in
                    let userData = userSnap?.data()
                    DispatchQueue.main.async {
                        self.displayItem = Item(
                            id: item.id,
                            image: (data["images"] as? [String])?.first ?? "",
                            images: data["images"] as? [String] ?? [],
                            title: data["category"] as? String ?? "",
                            description: data["detail"] as? String ?? "",
                            location: data["location"] as? String ?? "",
                            locationDetail: data["locationDetail"] as? String ?? "",
                            latitude: data["latitude"] as? Double ?? 0,
                            longitude: data["longitude"] as? Double ?? 0,
                            returnLocation: data["returnLocation"] as? String ?? "",
                            returnImage: data["returnImage"] as? String ?? "",
                            username: userData?["username"] as? String ?? "",
                            userId: userId,
                            date: data["date"] as? String ?? "",
                            type: data["type"] as? String ?? "",
                            status: newStatus,
                            userPhotoURL: userData?["photoURL"] as? String ?? ""
                        )
                    }
                }
            }
    }

    /// listener ชื่อผู้รับ — ถ้าคนรับเปลี่ยน username ใน Firestore ชื่อใน UI จะอัปเดตทันที
    func startClaimerListener(uid: String) {
        // ถ้า uid เดิมอยู่แล้ว ไม่ต้องสร้างใหม่
        guard claimerListener == nil || claimedBy != uid else { return }
        claimerListener?.remove()
        claimerListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }
                DispatchQueue.main.async {
                    self.claimedByName = data["username"] as? String ?? "ไม่ทราบชื่อ"
                }
            }
    }

    func deletePost() {
        Firestore.firestore().collection("posts").document(item.id).delete { error in
            if error == nil { dismiss() }
        }
    }

    func updatePostStatus() {
        let db = Firestore.firestore()
        guard let uid = currentUID else { return }

        // ดึงชื่อตัวเองก่อน update
        db.collection("users").document(uid).getDocument { snap, _ in
            let username = snap?.data()?["username"] as? String ?? "ไม่ทราบชื่อ"
            let phone = snap?.data()?["phone"] as? String ?? ""

            var updateData: [String: Any] = [
                "status": "claimed",
                "claimedBy": uid,
                "claimedByName": username
            ]
            if isFound { updateData["claimedByPhone"] = phone }

            db.collection("posts").document(item.id).updateData(updateData) { error in
                if error == nil {
                    self.status = .claimed
                    self.claimedBy = uid
                    self.claimedByName = username
                    self.sendClaimedNotification(db: db, claimerName: username, phone: phone)
                }
            }
        }
    }

    func sendClaimedNotification(db: Firestore, claimerName: String, phone: String) {
        guard !item.userId.isEmpty, isFound else { return }
        var notiData: [String: Any] = [
            "title": "มีคนมารับของแล้ว",
            "desc": "โพสต์นี้ของคุณมีคนมารับของแล้ว",
            "itemImage": displayItem.images.first ?? "",
            "postId": item.id,
            "category": displayItem.title,
            "images": displayItem.images,
            "type": displayItem.type,
            "location": displayItem.location,
            "locationDetail": displayItem.locationDetail,
            "returnLocation": displayItem.returnLocation,
            "username": displayItem.username,
            "userId": displayItem.userId,
            "date": displayItem.date,
            "postTitle": displayItem.title,
            "detail": displayItem.description,
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]
        if isFound { notiData["claimedByPhone"] = phone }
        db.collection("users").document(item.userId).collection("notifications").addDocument(data: notiData)
    }
    func checkPhoneBeforeClaim() {
        guard let uid = currentUID else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { snap, _ in
            let phone = snap?.data()?["phone"] as? String ?? ""
            DispatchQueue.main.async {
                if phone.isEmpty {
                    self.showNoPhoneAlert = true
                } else {
                    self.showConfirmAlert = true
                }
            }
        }
    }
}

// MARK: - DeferView
struct DeferView<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder _ content: @escaping () -> Content) { self.content = content }
    var body: Content { content() }
}

// MARK: - ReportSheetView
struct ReportSheetView: View {
    let item: Item
    @Environment(\.dismiss) var dismiss
    
    let reportReasons = ["ข้อมูลไม่ถูกต้อง", "ไม่ใช่เจ้าของจริง", "เนื้อหาไม่เหมาะสม", "สแปม / โฆษณา", "อื่น ๆ"]
    @State private var showDuplicateAlert = false
    @State private var selectedReason: String = ""
    @State private var otherReason: String = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    var canSubmit: Bool {
        if selectedReason.isEmpty { return false }
        if selectedReason == "อื่น ๆ" && otherReason.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        return true
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("เลือกเหตุผลในการรายงานโพสต์")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.darkText)
                    .padding(.horizontal, 20).padding(.top, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(reportReasons, id: \.self) { reason in
                            Button { selectedReason = reason } label: {
                                HStack {
                                    Text(reason).foregroundColor(.darkText).font(.system(size: 15))
                                    Spacer()
                                    Image(systemName: selectedReason == reason ? "record.circle" : "circle")
                                        .foregroundColor(selectedReason == reason ? .darkText : .gray)
                                        .font(.system(size: 20, weight: .light))
                                }
                                .padding(.vertical, 16).padding(.horizontal, 20).background(Color.white)
                            }
                        }
                        if selectedReason == "อื่น ๆ" {
                            TextField("โปรดระบุเหตุผลเพิ่มเติม...", text: $otherReason)
                                .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
                        }
                    }
                }
                
                Button(action: submitReport) {
                    Text(isSubmitting ? "กำลังส่ง..." : "รายงาน")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(canSubmit ? Color.appBackground : Color(hex: "#EAEAEA"))
                        .foregroundColor(canSubmit ? .white : .black).cornerRadius(8)
                }
                .disabled(!canSubmit || isSubmitting)
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ยกเลิก") { dismiss() }.foregroundColor(.gray)
                }
            }
            .alert("ขอบคุณที่แจ้งรายงาน", isPresented: $showSuccessAlert) {
                Button("ตกลง") { dismiss() }
            } message: { Text("เราจะตรวจสอบโพสต์นี้โดยเร็วที่สุด")
            .alert("แจ้งเตือน", isPresented: $showDuplicateAlert) {
                Button("ตกลง", role: .cancel) {}
            } message: {
                Text("คุณเคยรายงานโพสต์นี้แล้ว")
            }
          }
        }
    }
    
    func submitReport() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSubmitting = true
        let db = Firestore.firestore()
        let finalReason = selectedReason == "อื่น ๆ" ? "อื่น ๆ: \(otherReason)" : selectedReason
        
        // 1. ดึง username ก่อน
        db.collection("users").document(uid).getDocument { userSnap, _ in
            let username = userSnap?.data()?["username"] as? String ?? ""
            
            // 2. เช็ค duplicate — รายงานซ้ำไหม
            db.collection("reports")
                .whereField("postId", isEqualTo: item.id)
                .whereField("reportedBy", isEqualTo: uid)
                .getDocuments { snapshot, _ in
                    
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        // เคยรายงานแล้ว
                        isSubmitting = false
                        // แสดง alert แจ้ง
                        showDuplicateAlert = true
                        return
                    }
                    
                    // 3. ยังไม่เคยรายงาน → บันทึกได้เลย
                    let reportData: [String: Any] = [
                        "postId": item.id,
                        "reportedBy": uid,
                        //"reporterUsername": username,
                        "postOwnerId": item.userId,
                        "reason": finalReason,
                        "status": "pending",
                        "createdAt": Timestamp(date: Date()),
                        "reviewedAt": NSNull(),
                        "notified": false
                    ]
                    
                    db.collection("reports").addDocument(data: reportData) { error in
                        isSubmitting = false
                        if error == nil { showSuccessAlert = true }
                    }
                }
        }
    }
}
