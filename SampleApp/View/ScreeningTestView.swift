import SwiftUI

struct ScreeningTestView: View {
    let screenerType: ScreenerType

    @StateObject private var viewModel: ScreeningViewModel

    init(screenerType: ScreenerType) {
        self.screenerType = screenerType
        _viewModel = StateObject(wrappedValue: ScreeningViewModel(screenerType: screenerType))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Button(
                    action: {
                        viewModel.fetchAndScreenImagesFromCatAPI(count: 5)
                    },
                    label: {
                        Label("APIから猫画像を取得してスクリーニング", systemImage: "arrow.clockwise.icloud")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                viewModel.isLoading && Mirror(reflecting: viewModel).children
                                    .first(where: { $0.label == "screener" })?.value == nil ? Color
                                    .orange : (viewModel.isLoading ? Color.gray : Color.cyan)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                )
                .disabled(
                    viewModel.isLoading || Mirror(reflecting: viewModel).children
                        .first(where: { $0.label == "screener" })?.value == nil
                )
                .padding(.horizontal)
                .padding(.top)

                if !viewModel.fetchedImages.isEmpty {
                    Text("取得した画像: \(viewModel.fetchedImages.count)枚")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(viewModel.fetchedImages, id: \.self) { img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .cornerRadius(8)
                                    .padding(.trailing, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if viewModel.isLoading {
                    ProgressView(
                        Mirror(reflecting: viewModel).children.first(where: { $0.label == "screener" })?
                            .value == nil ? "スクリーナー初期化中..." : "処理中..."
                    )
                    .padding()
                }

                Text(viewModel.screeningSummary)
                    .font(.body)
                    .padding(.top)
                    .multilineTextAlignment(.center)

                if let errorMessage = viewModel.errorMessage {
                    Text("エラー: \(errorMessage)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                if !viewModel.safeImagesForDisplay.isEmpty {
                    Text("安全な画像 (".uppercased() + "\(viewModel.safeImagesForDisplay.count)枚)")
                        .font(.headline)
                        .padding(.top)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(viewModel.safeImagesForDisplay, id: \.self) { img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green, lineWidth: 3)
                                    )
                                    .padding(.trailing, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                Spacer()
            }
            .navigationTitle("\(screenerType.rawValue) Screener")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
        }
    }

    static var previews: some View {
        ScreeningTestView(screenerType: .multiClass)
    }
}
