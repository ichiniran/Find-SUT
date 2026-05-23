import SwiftUI

// MARK: - ENUM

enum ItemCategory: String, CaseIterable, Hashable {
    case all = "ทั้งหมด"
    case bag = "กระเป๋า / กระเป๋าสตางค์"
    case card = "บัตรนักศึกษา / บัตรประชาชน"
    case electronics = "โทรศัพท์ / อุปกรณ์อิเล็กทรอนิกส์"
    case money = "เงิน"
    case key = "กุญแจ"
    case accessory = "เครื่องประดับ"
    case clothes = "เสื้อผ้า"
    case other = "อื่น ๆ"
}

enum DateFilterType {
    case all, today, custom
}

// MARK: - MODEL

struct FilterOption {
    var category: ItemCategory = .all
    var location: String = "ทั้งหมด"
    var dateType: DateFilterType = .all
    var customDate: Date = Date()
    var statusFilter: String = "all"
}

// MARK: - VIEW

struct FilterView: View {

    @Binding var isShowing: Bool
    @Binding var filterOption: FilterOption
    @Binding var showStatusFilter: Bool
    
    @StateObject private var locationVM = LocationSearchViewModel()
    @State private var showDropdown: Bool = false
    
    @State private var selectedCategory: ItemCategory = .all
    @State private var selectedLocation: String = "ทั้งหมด"
    @State private var selectedDateType: DateFilterType = .all
    @State private var customDate: Date = Date()
    @State private var locationSearch: String = ""
    @State private var selectedStatus: String = "all"
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {

        VStack(spacing: 0) {

            // Header
            HStack {
                Text("ตัวกรอง").font(.headline)
                Spacer()
                Button { isShowing = false } label: {
                    Image(systemName: "xmark").foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: - สถานะโพสต์ (แสดงเฉพาะฝั่ง พบของ)
                    if showStatusFilter {
                        Text("สถานะโพสต์")
                            .font(.subheadline).bold()

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                statusChipItem("all", label: "ทั้งหมด")
                                statusChipItem("waiting", label: "รอเจ้าของมารับ")
                                statusChipItem("claimed", label: "เจ้าของรับไปแล้ว")
                            }
                        }
                    }

                    // MARK: - ประเภทสิ่งของ
                    Text("ประเภทสิ่งของ")
                        .font(.subheadline).bold()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) { chip(.all); chip(.bag) }
                        chip(.card)
                        HStack(spacing: 8) { chip(.electronics); chip(.money); chip(.key) }
                        HStack(spacing: 8) { chip(.accessory); chip(.clothes); chip(.other) }
                    }
                    
                    // MARK: - สถานที่
                    Text("สถานที่")
                        .font(.subheadline).bold()

                    // badge สถานที่ที่เลือก
                    if selectedLocation != "ทั้งหมด" {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.orange).font(.footnote)
                            Text(selectedLocation)
                                .font(.footnote).foregroundColor(.orange)
                            Spacer()
                            Button {
                                selectedLocation = "ทั้งหมด"
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(.systemGray3))
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(hex: "#FFF4EC"))
                        .cornerRadius(10)
                    }

                    // ช่องค้นหา
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(.systemGray3))
                        TextField("ค้นหาสถานที่...", text: $locationSearch)
                            .font(.footnote)
                            .focused($isSearchFocused)
                            .onChange(of: locationSearch) { newValue in
                                showDropdown = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                                locationVM.search(query: newValue)
                            }
                        if locationVM.isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else if !locationSearch.isEmpty {
                            Button {
                                locationSearch = ""
                                locationVM.reset()
                                showDropdown = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(.systemGray3))
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    // Dropdown
                    if showDropdown {
                        VStack(spacing: 0) {
                            if locationVM.suggestions.isEmpty {
                                HStack {
                                    Image(systemName: "magnifyingglass").font(.footnote)
                                        .foregroundColor(Color(.systemGray3))
                                    Text("ไม่พบสถานที่ \"" + locationSearch + "\"")
                                        .font(.footnote).foregroundColor(Color(.systemGray3))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(locationVM.suggestions, id: \.self) { loc in
                                    Button {
                                        selectedLocation = loc
                                        locationSearch = ""
                                        locationVM.reset()
                                        showDropdown = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin").font(.footnote)
                                                .foregroundColor(Color(.systemGray3))
                                            Text(loc).font(.footnote)
                                                .foregroundColor(Color(hex: "#333333"))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            if loc == selectedLocation {
                                                Image(systemName: "checkmark")
                                                    .font(.footnote).foregroundColor(.orange)
                                            }
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 12)
                                        .background(loc == selectedLocation
                                            ? Color(hex: "#FFF4EC") : Color.white)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray5), lineWidth: 1))
                    }

                    // MARK: - วันที่
                    Text("วันที่")
                        .font(.subheadline).bold()

                    VStack(alignment: .leading, spacing: 10) {
                        dateOption("ทั้งหมด", .all)
                        dateOption("วันนี้", .today)
                        dateOption("ระบุวันที่", .custom)

                        if selectedDateType == .custom {
                            DatePicker("", selection: $customDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(.orange)
                                .accentColor(.orange)
                                .frame(maxWidth: .infinity)
                                .frame(height: 350)
                                .clipped()
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)

            Divider()

            // ปุ่มล้าง / ตกลง
            HStack(spacing: 12) {
                Button("ล้าง") {
                    selectedCategory = .all
                    selectedLocation = "ทั้งหมด"
                    selectedDateType = .all
                    customDate = Date()
                    locationSearch = ""
                    selectedStatus = "all"
                    filterOption = FilterOption()
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color(.systemGray5))
                .foregroundColor(.orange)
                .cornerRadius(12)

                Button("ตกลง") {
                    filterOption = FilterOption(
                        category: selectedCategory,
                        location: selectedLocation,
                        dateType: selectedDateType,
                        customDate: customDate,
                        statusFilter: selectedStatus
                    )
                    isShowing = false
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(20)
        }
        .onAppear {
            selectedCategory = filterOption.category
            selectedLocation = filterOption.location
            selectedDateType = filterOption.dateType
            customDate = filterOption.customDate
            selectedStatus = filterOption.statusFilter
        }
        .task {
            await locationVM.loadAllLocations()
        }
    }

    // MARK: - CHIP ITEM (ประเภทสิ่งของ)
    func chip(_ item: ItemCategory) -> some View {
        let isSelected = selectedCategory == item
        return Text(item.rawValue)
            .font(.footnote)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color.orange : Color.white)
            .foregroundColor(isSelected ? .white : .black)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture { selectedCategory = item }
    }
    
    // MARK: - STATUS CHIP ITEM (สถานะโพสต์)
    func statusChipItem(_ key: String, label: String) -> some View {
        let isSelected = selectedStatus == key
        return Text(label)
            .font(.footnote)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color.orange : Color.white)
            .foregroundColor(isSelected ? .white : .black)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture { selectedStatus = key }
    }

    // MARK: - DATE
    func dateOption(_ title: String, _ type: DateFilterType) -> some View {
        HStack {
            radioCircle(selectedDateType == type)
            Text(title)
        }
        .onTapGesture { selectedDateType = type }
    }

    func radioCircle(_ selected: Bool) -> some View {
        ZStack {
            Circle().stroke(Color.orange, lineWidth: 2)
            if selected {
                Circle().fill(Color.orange).frame(width: 12, height: 12)
            }
        }
        .frame(width: 20, height: 20)
    }
}
