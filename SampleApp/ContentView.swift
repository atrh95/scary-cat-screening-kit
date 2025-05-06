import SwiftUI
import CatScreeningKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            // Image 1
            VStack(alignment: .center, spacing: 8) {
                Text("Image 1 (Not Scary?)").font(.headline)
                if viewModel.isLoading1 {
                    ProgressView()
                } else if let image = viewModel.image1 {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                } else {
                    Text("Loading Image 1...")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .frame(height: 150)
                }
                // 結果リスト
                ForEach(viewModel.results1, id: \.self) { result in
                    Text(result)
                        .font(.caption)
                }
                if let error = viewModel.error1 {
                    Text("Last Error: \(error)").foregroundColor(.red).font(.caption)
                }
            }
            .padding(.horizontal)

            Divider()

            // Image 2
            VStack(alignment: .center, spacing: 8) {
                Text("Image 2 (Scary?)").font(.headline)
                if viewModel.isLoading2 {
                    ProgressView()
                } else if let image = viewModel.image2 {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                } else {
                    Text("Loading Image 2...")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .frame(height: 150)
                }
                // 結果リスト
                ForEach(viewModel.results2, id: \.self) { result in
                    Text(result)
                        .font(.caption)
                }
                if let error = viewModel.error2 {
                    Text("Last Error: \(error)").foregroundColor(.red).font(.caption)
                }
            }
            .padding(.horizontal)

            Button("Fetch & Screen Random Cats") {
                viewModel.fetchAndProcessRandomImages()
            }
            .padding(.top)

            Spacer()
        }
        .padding(.top)
        .onAppear {
            viewModel.processImage1()
            viewModel.processImage2()
        }
    }
}

#Preview {
    ContentView()
}
