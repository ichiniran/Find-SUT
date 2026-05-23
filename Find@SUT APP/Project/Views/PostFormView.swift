import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
// MARK: - Location Model
struct LocationEntry: Hashable {
    let displayName: String   // ชื่อที่แสดงให้ user เห็น / พิมพ์
    let searchAlias: String   // ชื่อที่ใช้ค้นใน MKLocalSearch
    let fixedLat: Double?     // ถ้ามีพิกัดตายตัว ใส่เลย (nil = ค้นหาปกติ)
    let fixedLng: Double?

    init(_ display: String, alias: String? = nil, lat: Double? = nil, lng: Double? = nil) {
        displayName = display
        searchAlias = alias ?? display
        fixedLat = lat
        fixedLng = lng
    }
}
// MARK: - Draggable Map View (UIViewRepresentable)
struct DraggableMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    var onDragEnd: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "ตำแหน่งที่เลือก"
        mapView.addAnnotation(annotation)
        context.coordinator.annotation = annotation

        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)

        // Long press to move marker
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard let annotation = context.coordinator.annotation else { return }
        if annotation.coordinate.latitude != coordinate.latitude ||
           annotation.coordinate.longitude != coordinate.longitude {
            annotation.coordinate = coordinate
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DraggableMapView
        var annotation: MKPointAnnotation?
        weak var mapView: MKMapView?

        init(_ parent: DraggableMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            self.mapView = mapView
            let id = "draggablePin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            }
            view?.annotation = annotation
            view?.isDraggable = true
            view?.markerTintColor = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
            return view
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending, let coord = view.annotation?.coordinate {
                parent.coordinate = coord
                parent.onDragEnd(coord)
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            parent.coordinate = coord
            annotation?.coordinate = coord
            parent.onDragEnd(coord)
        }
    }
}

// MARK: - PostFormView
struct PostFormView: View {

    // MARK: - Data
    let LOCATIONS: [LocationEntry]  = [
        LocationEntry("อาคารรัฐสีมาคุณากร (ตึกดิจิ)",
            lat: 14.8777464, lng: 102.0148758),

        LocationEntry("อาคารเรียนรวม 1",
            lat: 14.8812045, lng: 102.0172388),

        LocationEntry("ศูนย์บรรณสารและสื่อการศึกษา",
            lat: 14.8792862, lng: 102.0161660),

        LocationEntry("อาคารเรียนรวม 2",
            lat: 14.8821272, lng: 102.0149950),

        LocationEntry("โรงอาหารเรียนรวม 2",
            lat: 14.8807094, lng: 102.0161202),

        LocationEntry("โรงอาหารกาสะลองคำ",
            lat: 14.8969424, lng: 102.0127062),

        LocationEntry("อาคารขนส่ง มหาวิทยาลัยเทคโนโลยีสุรนารี",
            lat: 14.8779646, lng: 102.0214334),

        LocationEntry("โรงอาหารกลาง (ตลาดวันพุธ ศุกร์)",
            lat: 14.8770106, lng: 102.0202693),

        LocationEntry("SUT Sport and Health Center (ฟิตเนท)",
            lat: 14.8869306, lng: 102.0177276),

        LocationEntry("สวนสุขภาพอ่างสุระ 2 Ang Sura 2 Healthy Park",
            lat: 14.8769115, lng: 102.0089866),

        LocationEntry("สระสามแสน",
            lat: 14.8786933, lng: 102.0086166),

        LocationEntry("หอพักสุรนิเวศ 1",
            lat: 14.8952312, lng: 102.0151869),

        LocationEntry("หอพักสุรนิเวศ 2",
            lat: 14.8961683, lng: 102.0150721),

        LocationEntry("หอพักสุรนิเวศ 3",
            lat: 14.8962607, lng: 102.0141534),

        LocationEntry("หอพักสุรนิเวศ 4",
            lat: 14.8971072, lng: 102.0137093),

        LocationEntry("หอพักสุรนิเวศ 5",
            lat: 14.8976346, lng: 102.0132898),

        LocationEntry("หอพักสุรนิเวศ 6",
            lat: 14.8986242, lng: 102.0141063),

        LocationEntry("หอพักสุรนิเวศ 7",
            lat: 14.8968456, lng: 102.0116974),

        LocationEntry("หอพักนักศึกษาชาย สุรนิเวศ 7",
            lat: 14.8971698, lng: 102.0112184),

        LocationEntry("หอพักสุรนิเวศ 8",
            lat: 14.8966581, lng: 102.0108101),

        LocationEntry("หอพักสุรนิเวศ 9",
            lat: 14.8964772, lng: 102.0099544),

        LocationEntry("หอพักสุรนิเวศ 10",
            lat: 14.8958422, lng: 102.0096897),

        LocationEntry("หอพักสุรนิเวศ 11",
            lat: 14.8985277, lng: 102.0107428),

        LocationEntry("หอพักสุรนิเวศ 12",
            lat: 14.8977294, lng: 102.0105926),

        LocationEntry("หอพักสุรนิเวศ 13 (โซนล่าง)",
            lat: 14.8998669, lng: 102.0115317),

        LocationEntry("Suranives 14",
            lat: 14.8969663, lng: 102.0158565),

        LocationEntry("หอพักสุรนิเวศ 15",
            lat: 14.8917407, lng: 102.0187319),

        LocationEntry("หอพักสุรนิเวศ 16",
            lat: 14.8926635, lng: 102.0140863),

        LocationEntry("หอพักสุรนิเวศ 18",
            lat: 14.8928916, lng: 102.0122409),

        LocationEntry("หอพักสุรนิเวศ 19-22 STUDENTS DORMITORY 19-22",
            lat: 14.8933374, lng: 102.0117581),
        
        LocationEntry("งานทุนการศึกษา มทส.",
            lat: 14.88637128760002, lng: 102.01692613681224),

        LocationEntry("ส่วนกิจการนักศึกษา",
            lat: 14.886216384547637, lng: 102.01687031702598),

        LocationEntry("สนามสุรพลากรีฑาสถาน",
            lat: 14.888178470943636, lng: 102.0169408795747),

        LocationEntry("อาคารเครื่องมือ 1 (F1)",
            lat: 14.877941725003957, lng: 102.01740983539369),

        LocationEntry("อาคารเครื่องมือ 2 (F2)",
            lat: 14.877371776892518, lng: 102.01817255259138),

        LocationEntry("อาคารเครื่องมือ 3 (F3)",
            lat: 14.876490385568776, lng: 102.0184062856536),

        LocationEntry("อาคารเครื่องมือ 4 (F4)",
            lat: 14.87753341508014, lng: 102.01637616793596),

        LocationEntry("อาคารเครื่องมือ 5 (F5)",
            lat: 14.876538331668117, lng: 102.01690897957441),

        LocationEntry("อาคารเครื่องมือ 6 (F6)",
            lat: 14.875512109080335, lng: 102.01754897957446),

        LocationEntry("อาคารเครื่องมือ 7 (F7)",
            lat: 14.874958763732476, lng: 102.02148573724662),

        LocationEntry("อาคารเฉลิมพระเกียรติ 72 พรรษา (F9)",
            lat: 14.87464403117933, lng: 102.01628560285127),

        LocationEntry("อาคารเครื่องมือ 10 (F10)",
            lat: 14.876746716188157, lng: 102.01514225073825),

        LocationEntry("โรงอาหารครัวท่านท้าว",
            lat: 14.877080523594612, lng: 102.02028921026357),

        LocationEntry("โรงอาหารดอนตะวัน",
            lat: 14.891623366630919, lng: 102.01785739677246),

        LocationEntry("โรงอาหารพราวแสดทอง",
            lat: 14.880720042216469, lng: 102.0161921832806),

        LocationEntry("โรงเตี๊ยม มทส.",
            lat: 14.881200182615824, lng: 102.01623365629752),
      ]

    let CATEGORIES: [String] = [
        "กระเป๋า / กระเป๋าสตางค์", "บัตรนักศึกษา / บัตรประชาชน",
        "โทรศัพท์ / อุปกรณ์อิเล็กทรอนิกส์", "เงิน", "กุญแจ",
        "เครื่องประดับ", "เสื้อผ้า", "อื่น ๆ",
    ]

    // พิกัด fallback มทส. (ใช้เมื่อไม่ได้รับ GPS)
    static let SUT_FALLBACK = CLLocationCoordinate2D(latitude: 14.8775, longitude: 102.0170)

    enum PostType { case found, lost }

    var type: PostType
    @Environment(\.dismiss) var dismiss
    var existingItem: Item? = nil
    var isEditMode: Bool { existingItem != nil }
    @State private var showPostSuccessAlert = false
    // MARK: - State: Form fields
    @State private var images: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoadingExistingImages = false   // loading รูปเดิมตอน edit
    @State private var category = ""
    @State private var showCategoryDD = false
    @State private var otherCategory = ""
    @State private var detail = ""
    @State private var selectedDate = Date()
    @State private var locationDetail = ""
    @State private var returnLocation = ""
    @State private var returnImage: UIImage? = nil
    @State private var returnPickerItem: PhotosPickerItem?

    // MARK: - State: Map / Location
    @State private var locationSearch = ""          // ข้อความในช่องค้นหา
    @State private var showLocationDD = false
    @State private var markerCoord = SUT_FALLBACK   // พิกัดหมุด (เริ่มที่ มทส. → จะอัปเดตเป็น GPS จริงทันที onAppear)
    @State private var displayName = ""             // ชื่อที่แสดง
    @State private var confirmed = false            // ยืนยันตำแหน่งแล้วหรือยัง
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @StateObject private var locationManager = LocationManager()

    // MARK: - State: UI
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var hideTabBar = true
    @State private var mapKey = UUID()              // force re-render map

    // กรอง LOCATIONS ตาม keyword
    // กรองจาก displayName
    var filteredLocations: [LocationEntry] {
        locationSearch.trimmingCharacters(in: .whitespaces).isEmpty
            ? LOCATIONS
            : LOCATIONS.filter { $0.displayName.localizedCaseInsensitiveContains(locationSearch) }
    }
    // MARK: - Labels
    var labels: (header: String, category: String, categoryPlaceholder: String,
                 categoryOther: String, detail: String, dateLabel: String, locationLabel: String) {
        if type == .found {
            return ("แจ้งพบของ", "ประเภทของที่พบ", "เลือกประเภทสิ่งของที่พบ",
                    "โปรดระบุประเภทสิ่งของที่พบ", "อธิบายลักษณะของที่พบ...",
                    "วันที่พบ", "สถานที่พบ")
        } else {
            return ("แจ้งของหาย", "ประเภทของที่หาย", "เลือกประเภทสิ่งของที่หาย",
                    "โปรดระบุประเภทสิ่งของที่หาย", "อธิบายลักษณะของที่หาย...",
                    "วันที่หาย", "สถานที่หาย")
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── รูปสิ่งของ ──
                    sectionLabel("อัปโหลดรูปสิ่งของ", topPad: 4)
                    imagePickerRow
                        .padding(.bottom, 16)

                    // ── ประเภทของ ──
                    sectionLabel(labels.category)
                    categoryDropdown
                        .padding(.bottom, 16)

                    // ── รายละเอียด ──
                    sectionLabel("รายละเอียด")
                    textAreaField($detail, placeholder: labels.detail)
                        .padding(.bottom, 16)

                    // ── วันที่ ──
                    sectionLabel(labels.dateLabel)
                    datePickerField
                        .padding(.bottom, 16)

                    // ── สถานที่ ══
                    sectionLabel(labels.locationLabel)
                    locationSearchField
                    if showLocationDD { locationDropdown }
                    if !searchResults.isEmpty { nominatimResults }

                    // แผนที่
                    mapSection
                        .padding(.top, 10)

                    // ปุ่มยืนยัน
                    if !confirmed { confirmButton.padding(.top, 10) }

                    // รายละเอียดสถานที่
                    sectionLabel("รายละเอียดสถานที่")
                        .padding(.top, 16)
                    textAreaField($locationDetail, placeholder: "เช่น ชั้น 2 ห้อง B201...")
                        .padding(.bottom, 16)

                    // ── found only ──
                    if type == .found {
                        sectionLabel("สถานที่รับของคืน")
                        textAreaField($returnLocation, placeholder: "ระบุสถานที่ที่สามารถรับของคืนได้...")
                            .padding(.bottom, 16)

                        sectionLabel("อัปโหลดรูปจุดฝาก")
                        returnImagePicker
                            .padding(.bottom, 16)
                    }

                    // ── ปุ่มโพสต์ / ยกเลิก ──
                    postButton
                        .padding(.top, 28)
                    cancelButton
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .background(Color(hex: "#FFFAF5").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert("เกิดข้อผิดพลาด", isPresented: $showErrorAlert) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("โพสต์สำเร็จแล้ว", isPresented: $showPostSuccessAlert) {
            Button("รับทราบ") { dismiss() }
        } message: {
            Text("หากมีผู้มารับของ กรุณาให้ผู้รับฝาก (เช่น รปภ. หรือเจ้าหน้าที่) หรือตัวคุณเองตรวจสอบหน้าจอการกดยืนยันการรับของของผู้มารับให้เรียบร้อย ระบบจะบันทึกเบอร์มือถือของผู้มารับไว้ทุกครั้ง")
        }
        .onAppear {
            hideTabBar = true
            populateIfEdit()
            if !isEditMode { locationManager.requestLocation() }
        }
        .onReceive(locationManager.$userLocation) { coord in
            // อัปเดตหมุดเป็น GPS จริงของผู้ใช้ครั้งแรก (เฉพาะกรณีไม่ใช่ edit และยังไม่ยืนยัน)
            guard let coord, !isEditMode, !confirmed else { return }
            moveTo(lat: coord.latitude, lng: coord.longitude)
        }
        .onDisappear { hideTabBar = false }
    }

    // MARK: - Header
    var headerView: some View {
            HStack {
                Button { resetForm(); dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(type == .found ? "โพสต์พบของ" : "โพสต์ของหาย")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding()
            .background(Color.formBackground)
            .foregroundColor(Color.darkText)
            .overlay(
                Rectangle()
                    .fill(Color(hex: "#5A4633"))
                    .frame(height: 0.5),
                alignment: .bottom
            )
        }

    // MARK: - Image Picker Row
    var imagePickerRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // ปุ่มเพิ่มรูป
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 3, matching: .images) {
                        imageBoxView(icon: "camera.fill", label: "เพิ่มรูป")
                    }
                    .onChange(of: selectedItems) {
                        Task {
                            var loaded: [UIImage] = []
                            for item in selectedItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let ui = UIImage(data: data) { loaded.append(ui) }
                            }
                            await MainActor.run { images = loaded }
                        }
                    }

                    // แสดงรูปที่เลือก / โหลดแล้ว
                    if isLoadingExistingImages {
                        // loading รูปเดิมจาก URL ตอน edit
                        ForEach(0..<(existingItem?.images.count ?? 0), id: \.self) { _ in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 100, height: 100)
                                ProgressView()
                            }
                        }
                    } else {
                        ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(12).clipped()
                                Button { images.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "#F97316"))
                                        .background(Color.white.clipShape(Circle()))
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .padding(.top, 8)   // ← ขยับลงมาให้พ้น label
            }
        }
    }

    func imageBoxView(icon: String, label: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            .foregroundColor(Color(hex: "#FBAA58"))
            .frame(width: 100, height: 100)
            .background(Color(hex: "#FFF8F3").cornerRadius(12))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 24)).foregroundColor(Color(hex: "#FBAA58"))
                    Text(label).font(.system(size: 11)).foregroundColor(Color(hex: "#FBAA58"))
                }
            )
    }

    // MARK: - Category Dropdown
    var categoryDropdown: some View {
        VStack(spacing: 0) {
            // trigger button
            Button { withAnimation { showCategoryDD.toggle() } } label: {
                HStack {
                    Text(category.isEmpty ? labels.categoryPlaceholder : category)
                        .font(.system(size: 14))
                        .foregroundColor(category.isEmpty ? Color(hex: "#bbbbbb") : Color(hex: "#333333"))
                    Spacer()
                    Image(systemName: showCategoryDD ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FBAA58"))
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
                .cornerRadius(12)
            }

            if showCategoryDD {
                VStack(spacing: 0) {
                    ForEach(CATEGORIES, id: \.self) { item in
                        Button {
                            category = item
                            withAnimation { showCategoryDD = false }
                        } label: {
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#5A4633"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        Divider().background(Color(hex: "#FFF0E6"))
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }

            if category == "อื่น ๆ" {
                TextField(labels.categoryOther, text: $otherCategory)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
                    .cornerRadius(12)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Date Picker
    var datePickerField: some View {
        DatePicker(labels.dateLabel, selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.compact)
            .font(.system(size: 14))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
            .cornerRadius(12)
    }

    // MARK: - Location Search Field
    var locationSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#FBAA58"))
            TextField("พิมพ์ชื่ออาคาร หรือสถานที่...", text: $locationSearch,
                      onEditingChanged: { editing in
                          // เปลี่ยนจาก if editing { showLocationDD = true }
                          if editing {
                              showLocationDD = !locationSearch.trimmingCharacters(in: .whitespaces).isEmpty
                          }
                      },
                      onCommit: { doMKSearch(locationSearch) })
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#333333"))
                .onChange(of: locationSearch) { _ in
                    // เปลี่ยนจาก showLocationDD = true
                    showLocationDD = !locationSearch.trimmingCharacters(in: .whitespaces).isEmpty
                    confirmed = false
                    searchResults = []
                }
            if isSearching {
                ProgressView().scaleEffect(0.8)
            } else if !locationSearch.isEmpty {
                Button {
                    locationSearch = ""; showLocationDD = false
                    searchResults = []; displayName = ""; confirmed = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#bbbbbb"))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
        .cornerRadius(12)
    }

    // MARK: - Location Dropdown (LOCATIONS list + search button)
    var locationDropdown: some View {
        VStack(spacing: 0) {
            ForEach(filteredLocations, id: \.self) { entry in
                Button { selectFromList(entry) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FBAA58"))
                        Text(entry.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#5A4633"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                Divider().background(Color(hex: "#FFF0E6"))
            }

            if !locationSearch.trimmingCharacters(in: .whitespaces).isEmpty {
                Button { doMKSearch(locationSearch) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#F97316"))
                        Text("ค้นหา \"\(locationSearch)\" บนแผนที่")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#F97316"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(hex: "#FFF4EC"))
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .padding(.top, 4)
    }

    // MARK: - MKLocalSearch results
    var nominatimResults: some View {
        VStack(spacing: 0) {
            ForEach(searchResults, id: \.self) { item in
                Button { selectSearchResult(item) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FBAA58"))
                        Text(item.name ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#5A4633"))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                Divider().background(Color(hex: "#FFF0E6"))
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .padding(.top, 4)
    }

    // MARK: - Map Section
    var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            DraggableMapView(coordinate: $markerCoord) { coord in
                confirmed = false
                reverseGeocode(coord: coord)
            }
            .id(mapKey)
            .frame(height: 260)
            .cornerRadius(12)
            .overlay(
                // hint label
                Text("ลากหมุดหรือกดค้างเพื่อปรับตำแหน่ง")
                    .font(.system(size: 11))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .padding(8),
                alignment: .bottom
            )

            // GPS button
            Button {
                locationManager.requestLocation()
                if let coord = locationManager.userLocation {
                    moveTo(lat: coord.latitude, lng: coord.longitude)
                    reverseGeocode(coord: coord)
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color(hex: "#F97316"))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .padding(10)
        }
    }

    // MARK: - Confirm Button
    var confirmButton: some View {
        Button {
            if locationSearch.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "กรุณาพิมพ์ชื่อสถานที่ก่อนยืนยันค่ะ"
                showErrorAlert = true
                return
            }
            confirmed = true
            showLocationDD = false
            searchResults = []
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                Text("ยืนยันจุดนี้")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [Color(hex: "#FFBB6B"), Color(hex: "#F97316")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Return Location Image Picker
    var returnImagePicker: some View {
        HStack(spacing: 12) {
            // ปุ่มเพิ่ม/เปลี่ยนรูป
            PhotosPicker(selection: $returnPickerItem, matching: .images) {
                if returnImage == nil {
                    imageBoxView(icon: "camera.fill", label: "ถ่ายรูป")
                } else {
                    imageBoxView(icon: "arrow.triangle.2.circlepath", label: "เปลี่ยนรูป")
                }
            }
            .onChange(of: returnPickerItem) {
                Task {
                    if let item = returnPickerItem,
                       let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run { returnImage = ui }
                    }
                }
            }

            // รูปที่เลือก + ปุ่มลบ
            if let img = returnImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 100, height: 100)
                        .cornerRadius(12).clipped()
                    Button {
                        returnImage = nil
                        returnPickerItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#F97316"))
                            .background(Color.white.clipShape(Circle()))
                    }
                    .offset(x: 6, y: -6)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Post / Cancel Buttons
    var postButton: some View {
        Button { handlePost() } label: {
            Text(isLoading ? "กำลังอัปโหลด..." : (isEditMode ? "บันทึกการแก้ไข" : "โพสต์"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isLoading ? Color.gray : Color(hex: "#F97316"))
                .cornerRadius(14)
        }
        .disabled(isLoading)
    }

    var cancelButton: some View {
        Button { resetForm(); dismiss() } label: {
            Text("ยกเลิก")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#FBAA58"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#FBAA58"), lineWidth: 1.5))
        }
    }

    // MARK: - Helper Views
    func sectionLabel(_ text: String, topPad: CGFloat = 16) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(hex: "#5A4633"))
            .padding(.top, topPad)
            .padding(.bottom, 6)
    }

    func textAreaField(_ binding: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if binding.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#bbbbbb"))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }
            TextEditor(text: binding)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#333333"))
                .frame(height: 90)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .scrollContentBackground(.hidden)
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F0E6DA"), lineWidth: 1))
        .cornerRadius(12)
    }

    // MARK: - Location Logic

    /// ย้ายหมุดบนแผนที่
    func moveTo(lat: Double, lng: Double, name: String? = nil) {
        markerCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        if let name { displayName = name }
        confirmed = false
        mapKey = UUID()
    }

    /// เลือกจาก LOCATIONS → ค้นหาพิกัดด้วย MKLocalSearch
    func selectFromList(_ entry: LocationEntry) {
        locationSearch = entry.displayName   // แสดงชื่อจริง
        showLocationDD = false
        searchResults = []

        // ถ้ามีพิกัดตายตัว → ใช้เลย ไม่ต้องค้นหา
        if let lat = entry.fixedLat, let lng = entry.fixedLng {
            moveTo(lat: lat, lng: lng, name: entry.displayName)
            displayName = entry.displayName
            return
        }

        // ไม่มีพิกัด → ค้นหาด้วย alias
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = entry.searchAlias + " มหาวิทยาลัยเทคโนโลยีสุรนารี"
        req.region = MKCoordinateRegion(
            center: PostFormView.SUT_FALLBACK,
            latitudinalMeters: 10_000, longitudinalMeters: 10_000
        )
        MKLocalSearch(request: req).start { response, _ in
            DispatchQueue.main.async {
                isSearching = false
                if let item = response?.mapItems.first {
                    moveTo(lat: item.placemark.coordinate.latitude,
                           lng: item.placemark.coordinate.longitude,
                           name: entry.displayName)   // ← แสดงชื่อจริง ไม่ใช่ alias
                } else {
                    displayName = entry.displayName
                    errorMessage = "ไม่พบพิกัด ลองลากหมุดบนแผนที่เพื่อระบุตำแหน่งเองได้ค่ะ"
                    showErrorAlert = true
                }
            }
        }
    }

    /// ค้นหาสถานที่ทั่วไปด้วย MKLocalSearch
    func doMKSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        showLocationDD = false

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query + " มหาวิทยาลัยเทคโนโลยีสุรนารี นครราชสีมา"
        req.region = MKCoordinateRegion(
            center: PostFormView.SUT_FALLBACK,
            latitudinalMeters: 10_000, longitudinalMeters: 10_000
        )
        MKLocalSearch(request: req).start { response, _ in
            DispatchQueue.main.async {
                isSearching = false
                searchResults = response?.mapItems ?? []
                if let first = searchResults.first {
                    moveTo(lat: first.placemark.coordinate.latitude,
                           lng: first.placemark.coordinate.longitude,
                           name: first.name)
                }
            }
        }
    }

    /// เลือกจากผล MKLocalSearch
    func selectSearchResult(_ item: MKMapItem) {
        locationSearch = item.name ?? ""
        moveTo(lat: item.placemark.coordinate.latitude,
               lng: item.placemark.coordinate.longitude, name: item.name)
        searchResults = []
    }

    /// Reverse geocode ด้วย CLGeocoder
    func reverseGeocode(coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { placemarks, _ in
            DispatchQueue.main.async {
                if let p = placemarks?.first {
                    displayName = [p.name, p.subLocality, p.locality]
                        .compactMap { $0 }.joined(separator: ", ")
                }
            }
        }
    }

    // MARK: - Edit Mode Populate
    func populateIfEdit() {
        guard let item = existingItem else { return }

        // category
        if CATEGORIES.contains(item.title) {
            category = item.title
        } else if !item.title.isEmpty && item.title != "-" {
            category = "อื่น ๆ"; otherCategory = item.title
        }

        if LOCATIONS.contains(where: { $0.displayName == item.location }) {
            locationSearch = item.location
        } else if !item.location.isEmpty && item.location != "-" {
            locationSearch = item.location
        }
        displayName = item.location

        // lat/lng — ใช้ item.latitude / item.longitude โดยตรง (Item model มี field นี้แล้ว)
        if item.latitude != 0 && item.longitude != 0 {
            markerCoord = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
            confirmed = true
            mapKey = UUID()
        }

        detail = item.description
        locationDetail = item.locationDetail
        returnLocation = item.returnLocation

        let fmt = DateFormatter(); fmt.dateFormat = "dd/MM/yyyy"
        if let d = fmt.date(from: item.date) { selectedDate = d }

        // โหลดรูปสิ่งของเดิมจาก URL
        if !item.images.isEmpty {
            isLoadingExistingImages = true
            Task {
                var loaded: [UIImage] = []
                for urlStr in item.images {
                    guard let url = URL(string: urlStr),
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let ui = UIImage(data: data) else { continue }
                    loaded.append(ui)
                }
                await MainActor.run {
                    images = loaded
                    isLoadingExistingImages = false
                }
            }
        }

        // โหลดรูปจุดฝากเดิม
        if !item.returnImage.isEmpty, let url = URL(string: item.returnImage) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let ui = UIImage(data: data) {
                    await MainActor.run { returnImage = ui }
                }
            }
        }
    }

    // MARK: - Reset
    func resetForm() {
        images = []; selectedItems = []
        category = ""; otherCategory = ""; detail = ""
        locationSearch = ""; showLocationDD = false
        markerCoord = PostFormView.SUT_FALLBACK   // fallback ก่อน แล้ว GPS จะ update ทีหลัง
        displayName = ""; confirmed = false; searchResults = []
        locationDetail = ""; returnLocation = ""; returnImage = nil
        selectedDate = Date()
        // ขอ GPS ใหม่หลัง reset
        locationManager.requestLocation()
    }

    // MARK: - Submit
    func handlePost() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "กรุณาเข้าสู่ระบบก่อนโพสต์"; showErrorAlert = true; return
        }

        let finalCategory: String
        if category == "อื่น ๆ" {
            guard !otherCategory.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "กรุณาระบุประเภทสิ่งของ"; showErrorAlert = true; return
            }
            finalCategory = otherCategory.trimmingCharacters(in: .whitespaces)
        } else if category.isEmpty {
            errorMessage = "กรุณาเลือกประเภทสิ่งของ"; showErrorAlert = true; return
        } else {
            finalCategory = category
        }

        if locationSearch.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "กรุณาระบุสถานที่"; showErrorAlert = true; return
        }
        if !confirmed {
            errorMessage = "กรุณายืนยันตำแหน่งบนแผนที่ก่อนค่ะ"; showErrorAlert = true; return
        }

        let fmt = DateFormatter(); fmt.dateFormat = "dd/MM/yyyy"
        let dateString = fmt.string(from: selectedDate)

        Task {
            isLoading = true
            defer { isLoading = false }

            // Upload images
            var imageURLs: [String] = existingItem?.images ?? []
            if !images.isEmpty {
                imageURLs = []
                for img in images {
                    if let url = await uploadToCloudinary(image: img) { imageURLs.append(url) }
                }
                if imageURLs.isEmpty {
                    errorMessage = "อัปโหลดรูปไม่สำเร็จ"; showErrorAlert = true; return
                }
            }

            var returnImageURL: String = existingItem?.returnImage ?? ""
            if let img = returnImage {
                returnImageURL = await uploadToCloudinary(image: img) ?? ""
            }

            let db = Firestore.firestore()
            let userDoc = try? await db.collection("users").document(user.uid).getDocument()
            let username = userDoc?.data()?["username"] as? String ?? "Unknown"
            let photoURL = userDoc?.data()?["photoURL"] as? String ?? ""

            var postData: [String: Any] = [
                "images": imageURLs,
                "category": finalCategory,
                "detail": detail,
                "date": dateString,
                "location": locationSearch,
                "locationName": displayName.isEmpty ? locationSearch : displayName,
                "locationDetail": locationDetail,
                "latitude": markerCoord.latitude,
                "longitude": markerCoord.longitude,
                "locationConfirmed": true,
                "type": type == .found ? "found" : "lost",
                "username": username,
                "userPhotoURL": photoURL,
                "updatedAt": Timestamp(date: Date()),
            ]

            if type == .found {
                postData["returnLocation"] = returnLocation
                postData["returnImage"] = returnImageURL
            }

            do {
                if let item = existingItem {
                    try await db.collection("posts").document(item.id).updateData(postData)
                } else {
                    postData["status"] = "waiting"
                    postData["userId"] = user.uid
                    postData["createdAt"] = Timestamp(date: Date())
                    let ref = try await db.collection("posts").addDocument(data: postData)
                    try await ref.setData(["postId": ref.documentID], merge: true)
                }
                await MainActor.run {
                    if !isEditMode && type == .found {
                        showPostSuccessAlert = true
                    } else {
                        dismiss()
                    }
                }
            } catch {
                errorMessage = "ไม่สามารถบันทึกข้อมูลได้: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    // MARK: - Cloudinary Upload
    func uploadToCloudinary(image: UIImage) async -> String? {
        let resized = image.resized(toWidth: 800) ?? image
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }

        let url = URL(string: "https://api.cloudinary.com/v1_1/dy9lc24op/image/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n")
        append("findsut\r\n")
        append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (resData, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = String(data: resData, encoding: .utf8) ?? "Unknown"
                await MainActor.run { errorMessage = "Cloudinary Error: \(msg)"; showErrorAlert = true }
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: resData) as? [String: Any]
            return json?["secure_url"] as? String
        } catch {
            await MainActor.run { errorMessage = "Network Error: \(error.localizedDescription)"; showErrorAlert = true }
            return nil
        }
    }
}

// MARK: - UIImage resize extension
extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let h = CGFloat(ceil(width / size.width * size.height))
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: h), false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: CGSize(width: width, height: h)))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PostFormView(type: .found)
    }
}
