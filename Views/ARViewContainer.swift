import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import simd

struct ARViewContainer: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let userLatitude: Double
    let userLongitude: Double
    /// Altitudine dell’utente in metri
    let userAltitude: Double
    let showObject: Bool
    let filename: String
    let provaAttuale: Int
    /// Distanza massima di visibilità in metri
    let visibility: Double

    // Coordinator to hold the current anchor, avoiding re-creation each update
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var currentAnchor: AnchorEntity?
        /// Prova per cui abbiamo già caricato i modelli
        var loadedProva: Int?
    }
    
    /// Cache per evitare di ricaricare ripetutamente lo stesso USDZ
    private static var modelCache: [String: ModelEntity] = [:]

    /// Ritorna un clone del ModelEntity per il filename dato
    private func modelEntity(for filename: String) -> ModelEntity? {
        if let cached = ARViewContainer.modelCache[filename] {
            return cached.clone(recursive: true)
        }
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("⚠️ Modello non trovato nel bundle: \\(filename)")
            return nil
        }
        do {
            let entity = try Entity.load(contentsOf: url)
            guard let modelEntity = entity as? ModelEntity else {
                print("⚠️ Entity caricata non è ModelEntity: \\(filename)")
                return nil
            }
            ARViewContainer.modelCache[filename] = modelEntity
            return modelEntity.clone(recursive: true)
        } catch {
            print("⚠️ Errore caricamento modello \\(filename): \\(error)")
            return nil
        }
    }

    /// Fetch the list of USDZ filenames for the current prova from server
    private func fetchModelList() async -> [String] {
        guard let url = URL(string: "https://tavernadeldrago.it/arprova/api.php/models?prova=\(provaAttuale)") else {
            print("⚠️ URL invalido per prova \(provaAttuale)")
            return []
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("❌ fetchModelList HTTP status: \(http.statusCode)")
                return []
            }
            let models = try JSONDecoder().decode([ARModel].self, from: data)
            return models.map { $0.filename }
        } catch {
            print("❌ Errore fetchModelList: \(error)")
            return []
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let worldConfig = ARWorldTrackingConfiguration()
        worldConfig.worldAlignment = .gravity
        worldConfig.planeDetection = [.horizontal]
        arView.session.run(worldConfig)

        Task {
            let list = await fetchModelList()
            await Self.prefetch(models: list)
        }

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // Compute distance between user and model location
        let modelLocation = CLLocation(latitude: latitude, longitude: longitude)
        let userLocation  = CLLocation(latitude: userLatitude, longitude: userLongitude)
        let distance = userLocation.distance(from: modelLocation)
        print("🔍 Distance to \(filename): \(distance) m, visibility threshold: \(visibility) m")
        // Show/hide based on visibility radius
        if distance > visibility {
            if let existing = context.coordinator.currentAnchor {
                print("🚫 Hiding model \(filename): out of range")
                arView.scene.removeAnchor(existing)
                context.coordinator.currentAnchor = nil
            }
            return
        } else {
            if context.coordinator.currentAnchor == nil {
                print("✅ Entered range for \(filename), adding model")
            }
        }

        // If prova or no anchor, (re)load for current prova
        if context.coordinator.currentAnchor == nil || context.coordinator.loadedProva != provaAttuale {
            // Remove old anchor
            if let existing = context.coordinator.currentAnchor {
                arView.scene.removeAnchor(existing)
                context.coordinator.currentAnchor = nil
            }

            Task {
                let earthRadius = 6_371_000.0
                let deltaLat = latitude - userLatitude
                let deltaLon = longitude - userLongitude
                let north = deltaLat * .pi/180 * earthRadius
                let east  = deltaLon * .pi/180 * earthRadius * cos(userLatitude * .pi/180)

                let position = SIMD3<Float>(Float(east), 0, -Float(north))
                let anchorEntity = AnchorEntity(world: position)

                let list = await fetchModelList()
                await Self.prefetch(models: list)

                for file in list {
                    if let model = modelEntity(for: file) {
                        anchorEntity.addChild(model)
                    }
                }
                arView.scene.addAnchor(anchorEntity)
                context.coordinator.currentAnchor = anchorEntity
                context.coordinator.loadedProva = provaAttuale
            }
            return
        }

        // Otherwise, if anchor exists and within visibility, update nothing (geo anchors track automatically)
    }
}

// MARK: - Prefetch USDZ Models
extension ARViewContainer {
    /// Download and cache all USDZ models by filename.
    /// Call this after fetching your model list to pre-load assets.
    static func prefetch(models filenames: [String]) async {
        for filename in filenames {
            // Skip if already cached
            if modelCache[filename] != nil { continue }

            guard let remoteURL = URL(string: "https://tavernadeldrago.it/arprova/uploads/\(filename)") else {
                print("⚠️ URL remoto invalido per \(filename)")
                continue
            }
            do {
                // Download raw data
                let (data, response) = try await URLSession.shared.data(from: remoteURL)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    print("🌐 Prefetch status code: \(http.statusCode) for \(filename)")
                } else {
                    print("❌ Prefetch HTTP status non OK for \(filename)")
                    continue
                }

                // Write to a temp file with .usdz extension
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: fileURL)
                FileManager.default.createFile(atPath: fileURL.path, contents: data)

                // Load and cache the ModelEntity
                let entity = try await ModelEntity(contentsOf: fileURL)
                modelCache[filename] = entity
                print("✅ Prefetched and cached: \(filename)")
            } catch {
                print("❌ Prefetch error for \(filename): \(error)")
            }
        }
    }
}
