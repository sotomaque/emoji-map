import SwiftUI

struct CategorySelectorDemo: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Category Selector")
                .font(.title)
                .fontWeight(.bold)
            
            CategorySelector()
                .padding(.horizontal)
            
            Spacer()
            
            Text("Selected categories will be shown here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 50)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    CategorySelectorDemo()
} 