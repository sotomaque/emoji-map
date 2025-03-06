import SwiftUI

struct LocationPermissionView: View {
    var onOpenSettings: () -> Void
    var onContinueWithoutLocation: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.bottom, 10)
            
            // Title
            Text("Location Access Required")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 12) {
                Text("Emoji Map needs access to your location to show nearby places.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("You can enable location access in Settings, or continue without location-based features.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: onContinueWithoutLocation) {
                    Text("Continue Without Location")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: Preview
struct LocationPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).edgesIgnoringSafeArea(.all)
            
            LocationPermissionView(
                onOpenSettings: {},
                onContinueWithoutLocation: {}
            )
        }
    }
} 