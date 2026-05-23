import SwiftUI
import FirebaseFirestore

// MARK: - Models
struct AdminReport: Identifiable {
    let id: String
    let postId: String
    let reportedBy: String
    let reporterUsername: String
    let reason: String
    var status: String  // "pending" | "reviewed"
    let createdAt: Date?
    let reviewedAt: Date?
    let notified: Bool
}

struct AdminReportPost {
    let id: String
    let type: String
    let category: String
    let detail: String
    let images: [String]
    let location: String
    let locationDetail: String
    let returnLocation: String
    let returnImage: String
    let date: String
    let status: String
    let userId: String
    let username: String
    let latitude: Double
    let longitude: Double
}

// MARK: - View
struct AdminReportsView: View {

    @Environment(\.dismiss) var dismiss
    @State private var reports: [AdminReport] = []
    @State private var isLoading = true
    @State private var statusFilter: ReportStatusFilter = .all
    @State private var reasonFilter: String = "all"
    @State private var selectedReport: AdminReport? = nil
    @State private var selectedPost: AdminReportPost? = nil
    @State private var postOwnerUsername: String = ""
    @State private var postLoading = false
    @State private var actionLoading = false
    @State private var toastMessage: String? = nil
    @State private var toastIsError = false
    @State private var showBanConfirm = false
    @State private var previewImageURL: String? = nil
    @State private var reporterUsername: String = ""
    enum ReportStatusFilter: String, CaseIterable {
        case all      = "ทั้งหมด"
        case pending  = "รอตรวจ"
        case reviewed = "ตรวจแล้ว"

        var key: String {
            switch self {
            case .all: return "all"
            case .pending: return "pending"
            case .reviewed: return "reviewed"
            }
        }
    }

    let REASONS = ["ทุกประเภท", "ข้อมูลไม่ถูกต้อง", "ไม่ใช่เจ้าของจริง", "เนื้อหาไม่เหมาะสม", "สแปม / โฆษณา", "อื่น ๆ"]
    let REASON_ICONS: [String: String] = [
        "ข้อมูลไม่ถูกต้อง": "⚠️",
        "ไม่ใช่เจ้าของจริง": "🚫",
        "เนื้อหาไม่เหมาะสม": "🔞",
        "สแปม / โฆษณา": "📢",
        "อื่น ๆ": "💬"
    ]

    var pendingCount: Int { reports.filter { $0.status == "pending" }.count }

    var filteredReports: [AdminReport] {
        reports.filter { r in
            let matchStatus: Bool
            switch statusFilter {
            case .all:      matchStatus = true
            case .pending:  matchStatus = r.status == "pending"
            case .reviewed: matchStatus = r.status == "reviewed"
            }

            let matchReason: Bool

            if reasonFilter == "all" || reasonFilter == "ทุกประเภท" {
                matchReason = true
            } else if reasonFilter == "อื่น ๆ" {

                // ถ้าไม่ใช่เหตุผลมาตรฐาน → ถือว่าเป็นอื่น ๆ
                matchReason =
                    ![
                        "ข้อมูลไม่ถูกต้อง",
                        "ไม่ใช่เจ้าของจริง",
                        "เนื้อหาไม่เหมาะสม",
                        "สแปม / โฆษณา"
                    ].contains(r.reason)

            } else {
                matchReason = r.reason == reasonFilter
            }
            return matchStatus && matchReason
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            VStack(spacing: 0) {

                // HEADER
                ZStack {
                    Color.formBackground.ignoresSafeArea(edges: .top)
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Color.darkText)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("จัดการรายงาน")
                                .font(.headline)
                                .foregroundColor(Color.darkText)
                            if pendingCount > 0 {
                                Text("รอตรวจ \(pendingCount) รายการ")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#EF4444"))
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.left").opacity(0)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 56)

                Divider()

                // FILTER
                VStack(spacing: 10) {
                    // Status tabs
                    HStack(spacing: 8) {
                        ForEach(ReportStatusFilter.allCases, id: \.self) { f in
                            Button {
                                statusFilter = f
                            } label: {
                                Text(f.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(statusFilter == f ? Color.orange : Color.white)
                                    .foregroundColor(statusFilter == f ? .white : .gray)
                                    .cornerRadius(20)
                            }
                        }
                        Spacer()
                    }

                    // Reason picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(REASONS, id: \.self) { r in
                                let key = r == "ทุกประเภท" ? "all" : r
                                Button {
                                    reasonFilter = key
                                } label: {
                                    Text(r == "ทุกประเภท" ? r : "\(REASON_ICONS[r] ?? "") \(r)")
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(reasonFilter == key ? Color(hex: "#5A4633") : Color.white)
                                        .foregroundColor(reasonFilter == key ? .white : Color(hex: "#5A4633"))
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.formBackground)

                // LIST
                if isLoading {
                    Spacer()
                    ProgressView().tint(.orange)
                    Spacer()
                } else if filteredReports.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "flag.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("ไม่พบรายการที่ตรงกับเงื่อนไข")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredReports) { report in
                                reportCard(report)
                                    .onTapGesture { openDetail(report) }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.formBackground)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { fetchReports() }

            // TOAST
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text(toastIsError ? "" : "")
                        Text(msg)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(toastIsError ? Color(hex: "#EF4444") : Color(hex: "#22C55E"))
                    .cornerRadius(14)
                    .shadow(radius: 8)
                    .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // BOTTOM SHEET
            if selectedReport != nil {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeDetail() }

                VStack {
                    Spacer()
                    reportDetailSheet
                        .background(Color(hex: "#FFFAF5"))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(radius: 12)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }

            // IMAGE PREVIEW
            if let url = previewImageURL {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture { previewImageURL = nil }

                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().padding(20)
                    default:
                        ProgressView()
                    }
                }

                VStack {
                    HStack {
                        Spacer()
                        Button { previewImageURL = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                        }
                    }
                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedReport?.id)
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - Report Card
    func reportCard(_ report: AdminReport) -> some View {
        HStack(spacing: 14) {
            // Status indicator
            Circle()
                .fill(report.status == "pending" ? Color(hex: "#F97316") : Color(hex: "#22C55E"))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 5) {
                // Reason
                HStack(spacing: 6) {
                    Text("\(REASON_ICONS[report.reason] ?? "") \(report.reason)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#5A4633"))
                    Spacer()
                    // Status badge
                    Text(report.status == "pending" ? "รอตรวจ" : "ตรวจแล้ว")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(report.status == "pending"
                            ? Color(hex: "#FFF3E0")
                            : Color(hex: "#E8F5E9"))
                        .foregroundColor(report.status == "pending"
                            ? Color(hex: "#E65100")
                            : Color(hex: "#2E7D32"))
                        .cornerRadius(20)
                }

                // Reporter
                Text("รายงานโดย @\(report.reporterUsername.isEmpty ? String(report.reportedBy.prefix(10)) + "…" : report.reporterUsername)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                // Date
                if let date = report.createdAt {
                    Text(formatDate(date))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#a0856a"))
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Detail Sheet
    var reportDetailSheet: some View {
        VStack(spacing: 0) {

            // Handle bar
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // ── Report Info ──
                    sectionCard(title: "ข้อมูลการแจ้ง") {
                        if let report = selectedReport {
                            infoRow(label: "Report ID", value: String(report.id.prefix(16)) + "…", mono: true)
                            Divider().padding(.leading, 16)
                            infoRow(label: "Post ID", value: String(report.postId.prefix(16)) + "…", mono: true)
                            Divider().padding(.leading, 16)
                            infoRow(label: "รายงานโดย", value: "@\(reporterUsername.isEmpty ? report.reporterUsername : reporterUsername)")
                            Divider().padding(.leading, 16)
                            infoRow(label: "เหตุผล", value: "\(REASON_ICONS[report.reason] ?? "") \(report.reason)")
                            Divider().padding(.leading, 16)
                            infoRow(label: "วันที่แจ้ง", value: report.createdAt.map { formatDate($0) } ?? "-")
                            Divider().padding(.leading, 16)
                            infoRow(label: "สถานะ", value: report.status == "pending" ? "รอตรวจสอบ" : "ตรวจแล้ว")
                            if let reviewedAt = report.reviewedAt {
                                Divider().padding(.leading, 16)
                                infoRow(label: "ตรวจเมื่อ", value: formatDate(reviewedAt))
                            }
                        }
                    }

                    // ── Post Info ──
                    sectionCard(title: "ข้อมูลโพสต์ที่ถูกแจ้ง") {
                        if postLoading {
                            HStack {
                                Spacer()
                                ProgressView().tint(.orange)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else if let post = selectedPost {

                            // Type + status badges
                            HStack(spacing: 8) {
                                Text(post.type == "found" ? "พบของ" : "ของหาย")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(post.type == "found" ? Color(hex: "#E8F5E9") : Color(hex: "#FFF3E0"))
                                    .foregroundColor(post.type == "found" ? Color(hex: "#2E7D32") : Color(hex: "#E65100"))
                                    .cornerRadius(20)

                                if post.status == "rejected" {
                                    Text("🗑️ ถูกลบแล้ว")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color(hex: "#FFEBEE"))
                                        .foregroundColor(Color(hex: "#C62828"))
                                        .cornerRadius(20)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 10)


                            // Images
                            if !post.images.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(post.images.prefix(3), id: \.self) { imgUrl in
                                            AsyncImage(url: URL(string: imgUrl)) { phase in
                                                switch phase {
                                                case .success(let img):
                                                    img.resizable().scaledToFill()
                                                default:
                                                    Color(.systemGray5)
                                                }
                                            }
                                            .frame(width: 90, height: 90)
                                            .cornerRadius(10)
                                            .clipped()
                                            .onTapGesture { previewImageURL = imgUrl }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            // Info rows
                            VStack(spacing: 0) {
                                if !postOwnerUsername.isEmpty {
                                    infoRow(label: "เจ้าของโพสต์", value: "@\(postOwnerUsername)")
                                    Divider().padding(.leading, 16)
                                }
                                infoRow(label: "หมวดหมู่", value: post.category.isEmpty ? "-" : post.category)
                                Divider().padding(.leading, 16)
                                infoRow(label: "รายละเอียด", value: post.detail.isEmpty ? "-" : post.detail)
                                Divider().padding(.leading, 16)
                                infoRow(label: "วันที่", value: post.date.isEmpty ? "-" : post.date)
                                Divider().padding(.leading, 16)
                                infoRow(label: "สถานที่", value: post.location.isEmpty ? "-" : post.location)
                                if !post.locationDetail.isEmpty {
                                    Divider().padding(.leading, 16)
                                    infoRow(label: "รายละเอียดสถานที่", value: post.locationDetail)
                                }
                                if !post.returnLocation.isEmpty {
                                    Divider().padding(.leading, 16)
                                    infoRow(label: "สถานที่รับคืน", value: post.returnLocation)
                                }
                            }

                            // Map link
                            if post.latitude != 0 && post.longitude != 0 {
                                Button {
                                    let urlStr = "https://maps.apple.com/?q=\(post.latitude),\(post.longitude)"
                                    if let url = URL(string: urlStr) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "map.fill")
                                        Text("เปิดแผนที่")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(Color(hex: "#F97316"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "#FFF7F0"))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#F0E6DC"), lineWidth: 1))
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }

                        } else {
                            Text("ไม่พบข้อมูลโพสต์ (อาจถูกลบแล้ว)")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }

                    // ── Actions ──
                    if let report = selectedReport {
                        if report.status == "pending" {
                            HStack(spacing: 10) {
                                // ตรวจแล้ว ไม่ลบ
                                Button {
                                    handleReviewed()
                                } label: {
                                    Text(actionLoading ? "กำลังดำเนินการ..." : "ตรวจแล้ว (ไม่ลบ)")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color(hex: "#E8F5E9"))
                                        .foregroundColor(Color(hex: "#2E7D32"))
                                        .cornerRadius(14)
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#A5D6A7"), lineWidth: 1))
                                }
                                .disabled(actionLoading)

                                // ลบโพสต์
                                Button {
                                    handleRejectPost()
                                } label: {
                                    Text(actionLoading ? "..." : "ลบโพสต์")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            selectedPost?.status == "rejected"
                                                ? Color(.systemGray5)
                                                : Color(hex: "#FFEBEE")
                                        )
                                        .foregroundColor(
                                            selectedPost?.status == "rejected"
                                                ? .gray
                                                : Color(hex: "#C62828")
                                        )
                                        .cornerRadius(14)
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                                            selectedPost?.status == "rejected"
                                                ? Color(.systemGray4)
                                                : Color(hex: "#EF9A9A"),
                                            lineWidth: 1)
                                        )
                                }
                                .disabled(actionLoading || selectedPost?.status == "rejected")
                            }
                            .padding(.horizontal, 20)

                        } else {
                            // Reviewed note
                            HStack(spacing: 8) {
                                Text("Report นี้ได้รับการตรวจสอบแล้ว")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#2E7D32"))
                                if let reviewedAt = report.reviewedAt {
                                    Text("เมื่อ \(formatDate(reviewedAt))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#E8F5E9"))
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom,20)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
    }

    // MARK: - Sub Views
    func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#a0856a"))
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#F0E6DC"), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: mono ? .regular : .medium))
                .foregroundColor(Color(hex: "#5A4633"))
                .lineLimit(mono ? 1 : 4)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "th_TH")
        return formatter.string(from: date)
    }

    // MARK: - Firestore
    func fetchReports() {
        Firestore.firestore().collection("reports")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                DispatchQueue.main.async {
                    self.reports = docs.map { doc in
                        let data = doc.data()
                        return AdminReport(
                            id: doc.documentID,
                            postId: data["postId"] as? String ?? "",
                            reportedBy: data["reportedBy"] as? String ?? "",
                            reporterUsername: data["reporterUsername"] as? String ?? "",
                            reason: data["reason"] as? String ?? "",
                            status: data["status"] as? String ?? "pending",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                            reviewedAt: (data["reviewedAt"] as? Timestamp)?.dateValue(),
                            notified: data["notified"] as? Bool ?? false
                        )
                    }
                    self.isLoading = false
                }
            }
    }

    func openDetail(_ report: AdminReport) {
        selectedReport = report
        selectedPost = nil
        postOwnerUsername = ""
        postLoading = true
        reporterUsername = ""

        let db = Firestore.firestore()
        
        db.collection("users").document(report.reportedBy).getDocument { snap, _ in
                DispatchQueue.main.async {
                    self.reporterUsername = snap?.data()?["username"] as? String ?? report.reporterUsername
                }
            }


        db.collection("posts").document(report.postId).getDocument { snap, _ in
            if let data = snap?.data() {
                let userId = data["userId"] as? String ?? ""

                // ดึง username เจ้าของโพสต์
                db.collection("users").document(userId).getDocument { userSnap, _ in
                    DispatchQueue.main.async {
                        self.postOwnerUsername = userSnap?.data()?["username"] as? String ?? ""
                        self.selectedPost = AdminReportPost(
                            id: snap!.documentID,
                            type: data["type"] as? String ?? "",
                            category: data["category"] as? String ?? "",
                            detail: data["detail"] as? String ?? "",
                            images: data["images"] as? [String] ?? [],
                            location: data["location"] as? String ?? "",
                            locationDetail: data["locationDetail"] as? String ?? "",
                            returnLocation: data["returnLocation"] as? String ?? "",
                            returnImage: data["returnImage"] as? String ?? "",
                            date: data["date"] as? String ?? "",
                            status: data["status"] as? String ?? "",
                            userId: userId,
                            username: data["username"] as? String ?? "",
                            latitude: data["latitude"] as? Double ?? 0,
                            longitude: data["longitude"] as? Double ?? 0
                        )
                        self.postLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.selectedPost = nil
                    self.postLoading = false
                }
            }
        }
    }

    func closeDetail() {
        selectedReport = nil
        selectedPost = nil
        postOwnerUsername = ""
    }

    func showToast(_ msg: String, isError: Bool = false) {
        toastIsError = isError
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Actions
    func handleReviewed() {
        guard let report = selectedReport else { return }
        actionLoading = true
        let db = Firestore.firestore()

        db.collection("reports").document(report.id).updateData([
            "status": "reviewed",
            "reviewedAt": Timestamp(date: Date()),
            "notified": true
        ]) { error in
            DispatchQueue.main.async {
                actionLoading = false
                if error == nil {
                    sendNotification(report: report)
                    showToast("ตรวจสอบแล้ว ไม่มีการลบโพสต์")
                    closeDetail()
                } else {
                    showToast("เกิดข้อผิดพลาด กรุณาลองใหม่", isError: true)
                }
            }
        }
    }

    func handleRejectPost() {
        guard let report = selectedReport else { return }
        actionLoading = true
        let db = Firestore.firestore()

        db.collection("posts").document(report.postId).updateData(["status": "rejected"]) { _ in
            db.collection("reports").document(report.id).updateData([
                "status": "reviewed",
                "reviewedAt": Timestamp(date: Date()),
                "notified": true
            ]) { error in
                DispatchQueue.main.async {
                    actionLoading = false
                    if error == nil {
                        // โนติผู้รายงาน (เดิม)
                        sendNotification(report: report, type: "report_reviewed")
                        // โนติเจ้าของโพสต์ (ใหม่)
                        sendOwnerNotification(report: report)
                        showToast("ลบโพสต์เรียบร้อย และอัปเดตสถานะ report แล้ว")
                        closeDetail()
                    } else {
                        showToast("เกิดข้อผิดพลาด กรุณาลองใหม่", isError: true)
                    }
                }
            }
        }
    }

    // แก้ sendNotification เดิมให้รับ type
    func sendNotification(report: AdminReport, type: String = "report_reviewed") {
        guard !report.reportedBy.isEmpty else { return }
        let post = selectedPost

        let notiData: [String: Any] = [
            "type": type,
            "title": "ผลการตรวจสอบรายงาน",
            "desc": "โพสต์ที่คุณรายงานได้รับการตรวจสอบแล้ว",
            "postId": report.postId,
            "postTitle": post?.category ?? "",
            "detail": post?.detail ?? "",
            "location": post?.location ?? "",
            "locationDetail": post?.locationDetail ?? "",
            "receiveLocation": post?.returnLocation ?? "",
            "username": post?.username ?? "",
            "userId": post?.userId ?? "",
            "date": post?.date ?? "",
            "images": post?.images ?? [],
            "itemImage": post?.images.first ?? "",
            "category": post?.category ?? "",
            "latitude": post?.latitude ?? 0,
            "longitude": post?.longitude ?? 0,
            "currentStatus": "rejected",
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]

        Firestore.firestore()
            .collection("users").document(report.reportedBy)
            .collection("notifications").addDocument(data: notiData)
    }

    //  ฟังก์ชันใหม่ — โนติเจ้าของโพสต์
    func sendOwnerNotification(report: AdminReport) {
        guard let post = selectedPost, !post.userId.isEmpty else { return }

        let notiData: [String: Any] = [
            "type": "post_rejected_by_admin",
            "title": "โพสต์ของคุณถูกปิดกั้น",
            "desc": "โพสต์ของคุณถูกปิดกั้น เนื่องจากมีผู้รายงานว่า \"\(report.reason)\"",
            "postId": report.postId,
            "postTitle": post.category,
            "detail": post.detail,
            "location": post.location,
            "locationDetail": post.locationDetail,
            "receiveLocation": post.returnLocation,
            "username": post.username,
            "userId": post.userId,
            "date": post.date,
            "images": post.images,
            "itemImage": post.images.first ?? "",
            "category": post.category,
            "latitude": post.latitude,
            "longitude": post.longitude,
            "currentStatus": "rejected",
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]

        Firestore.firestore()
            .collection("users").document(post.userId)
            .collection("notifications").addDocument(data: notiData)
    }}
