import SwiftUI
import RealityKit
import CoreLocation
import Foundation
import AVFoundation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var altitude: Double = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        // Avvia subito gli aggiornamenti di posizione
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
            self.altitude = loc.altitude
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            print("Location access not authorized: \(status.rawValue)")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            print("Location access not authorized: \(status.rawValue)")
        }
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var models: [ARModel] = []
    @State private var provaAttuale: Int?
    // Persisted username from login
    @AppStorage("username") private var storedUsername: String = ""
    // Timer to poll current prova every 30 seconds
    @State private var provaTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    // Torch control state
    @State private var torchOn = false

    var body: some View {
        ZStack {
            if models.isEmpty {
                Text("Caricamento modelli in corso…")
                    .padding()
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(8)
            } else {
                ForEach(models, id: \.id) { model in
                    // Compute distance between user and this model
                    let userDistance = CLLocation(
                        latitude: locationManager.latitude,
                        longitude: locationManager.longitude
                    ).distance(
                        from: CLLocation(latitude: model.latitude, longitude: model.longitude)
                    )

                    ZStack {
                        ARViewContainer(
                            latitude: model.latitude,
                            longitude: model.longitude,
                            userLatitude: locationManager.latitude,
                            userLongitude: locationManager.longitude,
                            userAltitude: locationManager.altitude,
                            showObject: userDistance <= model.visibility,
                            filename: model.filename,
                            provaAttuale: self.provaAttuale ?? model.idProva,
                            visibility: model.visibility
                        )
                        .edgesIgnoringSafeArea(.all)

                        if userDistance > model.visibility {
                            VStack {
                                Text("Sei a \(Int(userDistance)) m dall'oggetto. Avvicinati entro \(Int(model.visibility)) m per vederlo.")
                                    .multilineTextAlignment(.center)
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
                        do {
                            try device.lockForConfiguration()
                            if torchOn {
                                device.torchMode = .off
                                torchOn = false
                            } else {
                                try device.setTorchModeOn(level: 1.0)
                                torchOn = true
                            }
                            device.unlockForConfiguration()
                        } catch {
                            print("Torch could not be used: \(error)")
                        }
                    }) {
                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }

            VStack {
                Spacer()
                VStack {
                    Text("Lat utente: \(locationManager.latitude)")
                    Text("Lon utente: \(locationManager.longitude)")
                }
                .padding()
                .background(Color.white.opacity(0.7))
                .cornerRadius(8)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            guard !storedUsername.isEmpty else { return }
            APIClient.shared.fetchCurrentProva(username: storedUsername) { success, prova, error in
                if success, let p = prova {
                    DispatchQueue.main.async {
                        self.provaAttuale = p
                        APIClient.shared.fetchModels(prova: p) { fetched in
                            let activeModels = fetched.filter { $0.active }
                            let filenames = activeModels.map(\.filename)
                            Task {
                                await ARViewContainer.prefetch(models: filenames)
                                DispatchQueue.main.async {
                                    self.models = activeModels
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(provaTimer) { _ in
            guard !storedUsername.isEmpty else { return }
            APIClient.shared.fetchCurrentProva(username: storedUsername) { success, prova, error in
                if success, let p = prova {
                    DispatchQueue.main.async {
                        self.provaAttuale = p
                        APIClient.shared.fetchModels(prova: p) { fetched in
                            let activeModels = fetched.filter { $0.active }
                            let filenames = activeModels.map(\.filename)
                            Task {
                                await ARViewContainer.prefetch(models: filenames)
                                DispatchQueue.main.async {
                                    self.models = activeModels
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
