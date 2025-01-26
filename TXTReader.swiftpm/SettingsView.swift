import SwiftUI

struct SettingsView: View {
    @Binding var backgroundColor: Color
    @Binding var textColor: Color
    @Binding var fontSize: CGFloat

    var body: some View {
        VStack {
            ColorPicker("Background Color", selection: $backgroundColor)
            ColorPicker("Text Color", selection: $textColor)
            Slider(value: $fontSize, in: 12...36, step: 1) {
                Text("Font Size")
            }
        }
        .padding()
    }
}
