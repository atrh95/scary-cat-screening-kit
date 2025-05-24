import Kingfisher
import ScaryCatScreeningKit
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
                                ForEach(viewModel.fetchedImages, id: \.url) { item in
                                    KFImage(item.url)
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color(uiColor: .secondarySystemBackground))
                                                .frame(height: 100)
                                                .cornerRadius(8)
                                        }
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
                                ForEach(viewModel.safeImagesForDisplay, id: \.url) { item in
                                    KFImage(item.url)
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color(uiColor: .secondarySystemBackground))
                                                .frame(height: 150)
                                                .cornerRadius(8)
                                        }
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

                    if !viewModel.unsafeImagesForDisplay.isEmpty {
                        Text("危険な画像 (".uppercased() + "\(viewModel.unsafeImagesForDisplay.count)枚)")
                            .font(.headline)
                            .padding(.top)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.unsafeImagesForDisplay, id: \.url) { result in
                                    VStack {
                                        KFImage(result.url)
                                            .placeholder {
                                                Rectangle()
                                                    .fill(Color(uiColor: .secondarySystemBackground))
                                                    .frame(height: 150)
                                                    .cornerRadius(8)
                                            }
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 150)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.red, lineWidth: 3)
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(result.features, id: \.featureName) { feature in
                                                HStack {
                                                    Text(feature.featureName)
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                    Text("(\(String(format: "%.1f", feature.confidence * 100))%)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    .padding(.trailing, 4)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom)
            }
            .navigationTitle("Scary Cat Screener")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
        }
    }
}
