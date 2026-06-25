import SwiftUI

struct OverlayLabelView: View {
    var body: some View {
        Text("窗口 1")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}