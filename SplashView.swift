import SwiftUI

struct SplashView: View {
    // Binding per nascondere la splash
    @Binding var showSplash: Bool
    @State private var logoOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("logo")   // sostituisci "your_logo" col nome dell’immagine in Assets
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .opacity(logoOpacity)
        }
        .onAppear {
            // Dopo 1s inizia fade‑out in 1s
            withAnimation(.easeOut(duration: 1.0).delay(1.0)) {
                logoOpacity = 0
            }
            // Dopo 2s nascondi la splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showSplash = false
            }
        }
    }
}
