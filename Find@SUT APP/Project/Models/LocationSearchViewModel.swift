import Foundation
import FirebaseFirestore
import Combine
@MainActor
class LocationSearchViewModel: ObservableObject {
    //var objectWillChange: ObservableObjectPublisher
    
    @Published var suggestions: [String] = []
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()
    private var allLocations: [String] = []

    func loadAllLocations() async {
        isLoading = true
        do {
            let snapshot = try await db.collection("posts").getDocuments()
            let names = snapshot.documents.compactMap {
                $0.data()["locationName"] as? String
            }
            allLocations = Array(Set(names)).sorted()
        } catch {
            print("Error loading locations: \(error)")
        }
        isLoading = false
    }

    func search(query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { suggestions = []; return }
        suggestions = allLocations.filter {
            $0.localizedCaseInsensitiveContains(q)
        }
    }

    func reset() { suggestions = [] }
}
