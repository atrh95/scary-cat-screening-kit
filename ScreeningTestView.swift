import SwiftUI

struct ScreeningTestView: View {
    @StateObject private var viewModel = ScreeningViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
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
                                    viewModel.isLoading && !viewModel.isScreenerReady ? Color.orange :
                                        (viewModel.isLoading ? Color.gray : Color.cyan)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    )
                    .disabled(
                        viewModel.isLoading || !viewModel.isScreenerReady
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
                            !viewModel.isScreenerReady ? "スクリーナー初期化中..." : "処理中..."
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

                    if !viewModel.scaryImagesForDisplay.isEmpty {
                        Text("検出された危険な特徴 (".uppercased() + "\(viewModel.scaryImagesForDisplay.count)枚)")
                            .font(.headline)
                            .padding(.top)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.scaryImagesForDisplay, id: \.self) { img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.red, lineWidth: 3)
                                        )
                                        .padding(.trailing, 4)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Image Screener")
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
        ScreeningTestView()
    }
}
