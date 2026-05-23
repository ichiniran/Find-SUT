import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    enum ItemType {
        case found, lost
    }

    let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]
    @Binding var hideTabBar: Bool
    @State private var items: [Item] = []
    @State private var searchText = ""
    @State private var selectedType: ItemType = .found
    @State private var showFilter = false
    
    @State private var foundFilterOption = FilterOption()
    @State private var lostFilterOption = FilterOption()
    
    @State private var showStatusFilter: Bool = true
    
    // ใช้อ่านค่าตัวกรองตาม Tab ปัจจุบัน
    var activeFilter: FilterOption {
        selectedType == .found ? foundFilterOption : lostFilterOption
    }
    
    // สร้าง Binding โยนให้ FilterView ตาม Tab ปัจจุบัน
    var currentFilterBinding: Binding<FilterOption> {
        Binding(
            get: { selectedType == .found ? foundFilterOption : lostFilterOption },
            set: { newValue in
                if selectedType == .found {
                    foundFilterOption = newValue
                } else {
                    lostFilterOption = newValue
                }
            }
        )
    }
    
    var filteredItems: [Item] {
        let today = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return items.filter { item in

            let matchType = item.type == (selectedType == .found ? "found" : "lost")

            // ── Status filter (ใช้เฉพาะฝั่ง found) ──
            let matchStatus: Bool
            if selectedType == .found {
                switch foundFilterOption.statusFilter {
                case "waiting": matchStatus = item.status == "waiting"
                case "claimed": matchStatus = item.status == "claimed"
                default:        matchStatus = true   // "all"
                }
            } else {
                matchStatus = true   // lost ไม่มี status filter
            }

            let matchSearch = searchText.isEmpty ||
                item.title.localizedCaseInsensitiveContains(searchText)

            let knownCategories = ItemCategory.allCases
                .filter { $0 != .all && $0 != .other }
                .map { $0.rawValue }

            let matchCategory: Bool
            switch activeFilter.category {
            case .all:
                matchCategory = true
            case .other:
                matchCategory = !knownCategories.contains(where: {
                    item.title.localizedCaseInsensitiveContains($0)
                })
            default:
                matchCategory = item.title.localizedCaseInsensitiveContains(activeFilter.category.rawValue)
            }

            let matchLocation: Bool
            if activeFilter.location == "ทั้งหมด" {
                matchLocation = true
            } else {
                matchLocation = item.location.localizedCaseInsensitiveContains(activeFilter.location)
            }

            func parseDate(_ str: String) -> Date? {
                let parts = str.split(separator: "/")
                guard parts.count == 3, let year = Int(parts[2]) else { return nil }
                let adYear = year > 2500 ? year - 543 : year
                return formatter.date(from: "\(parts[0])/\(parts[1])/\(adYear)")
            }

            let matchDate: Bool
            switch activeFilter.dateType {
            case .all:
                matchDate = true
            case .today:
                if let itemDate = parseDate(item.date) {
                    matchDate = calendar.isDate(itemDate, inSameDayAs: today)
                } else {
                    matchDate = true
                }
            case .custom:
                if let itemDate = parseDate(item.date) {
                    matchDate = calendar.isDate(itemDate, inSameDayAs: activeFilter.customDate)
                } else {
                    matchDate = true
                }
            }

            return matchType && matchStatus && matchSearch && matchCategory && matchLocation && matchDate
        }
    }

    var body: some View {
        ZStack {

            Color.formBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // HEADER
                VStack(spacing: 15) {

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 45)
                        .padding(.top, 25)

                    HStack {
                        tabButton(title: "พบของ", type: .found)
                        Spacer()
                        tabButton(title: "ของหาย", type: .lost)
                    }
                    .padding(.horizontal, 80)

                    GeometryReader { geo in
                        let width = geo.size.width / 2
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: 80, height: 4)
                            .offset(x: selectedType == .found
                                    ? width * 0.5 - 35
                                    : width * 1.5 - 45)
                            .animation(.easeInOut(duration: 0.25), value: selectedType)
                    }
                    .frame(height: 2)
                }
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFFAF5"), Color(hex: "#fff6ee")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                HStack(spacing: 10) {

                    HStack {
                        TextField("ค้นหา", text: $searchText)
                            .font(.system(size: 15))
                            .submitLabel(.search)
                            .onSubmit {
                                hideKeyboard()
                            }

                        Button {
                            hideKeyboard()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 15)
                    .frame(height: 45)
                    .background(Color.white)
                    .cornerRadius(20)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showFilter = true
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.gray)
                                .font(.system(size: 18, weight: .medium))

                            if activeFilter.category != .all ||
                                activeFilter.location != "ทั้งหมด" ||
                                activeFilter.dateType != .all ||
                                (selectedType == .found && activeFilter.statusFilter != "all") {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // GRID
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: DetailView(item: item, hideTabBar: $hideTabBar)){
                                CardView(item: item)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 5)
                }
            }
            .onAppear {
                fetchPosts()
                showStatusFilter = (selectedType == .found)
            }
            .onChange(of: selectedType) { newType in
                showStatusFilter = (newType == .found)
                // ไม่ต้อง reset statusFilter แล้ว เพราะตัวแปรถูกแยกกันชัดเจน
            }
            
            // FILTER
            if showFilter {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showFilter = false
                        }
                    }

                VStack {
                    Spacer()
                    FilterView(
                        isShowing: $showFilter,
                        filterOption: currentFilterBinding,
                        showStatusFilter: $showStatusFilter
                    )
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(radius: 12)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showFilter)
        // คำสั่งซ่อนแถบเมนูด้านล่างตอนหน้าต่าง Filter เปิดขึ้นมา
        .toolbar(showFilter ? .hidden : .visible, for: .tabBar)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func fetchPosts() {
        let db = Firestore.firestore()

        db.collection("posts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    print("Error:", error.localizedDescription)
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.items = documents.compactMap { doc in
                    let data = doc.data()
                    let type   = data["type"]   as? String ?? ""
                    let status = data["status"] as? String ?? "waiting"

                    if type == "lost"  && status != "waiting" { return nil }
                    if type == "found" && status != "waiting" && status != "claimed" { return nil }

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
                        type: type,
                        status: status,
                        userPhotoURL: data["userPhotoURL"] as? String ?? ""
                    )
                }
            }
    }
}

// MARK: - TAB BUTTON
extension HomeView {
    func tabButton(title: String, type: ItemType) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(selectedType == type ? Color.loginTitle : Color.gray)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    selectedType = type
                }
            }
    }
}

