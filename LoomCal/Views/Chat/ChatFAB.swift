import SwiftUI

struct ChatFAB: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image("LoomSource")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                ChatView(chatViewModel: chatViewModel)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Image("LoomAvatar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSheet = false }
                        }
                    }
                    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
