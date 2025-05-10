import SwiftUI

struct ScreeningTestView: View {
    // ScreenerType を受け取るためのプロパティ
    let screenerType: ScreenerType
    
    // ContentViewModel を StateObject として保持。screenerType を渡して初期化
    @StateObject private var viewModel: ScreeningViewModel
    
    init(screenerType: ScreenerType) {
        self.screenerType = screenerType
        _viewModel = StateObject(wrappedValue: ScreeningViewModel(screenerType: screenerType))
    }
    
    private var buttonBackgroundColor: Color {
        if viewModel.isLoading {
            // Check if 'screener' property is nil using Mirror
            let screenerIsNil = Mirror(reflecting: viewModel).children
                .first(where: { $0.label == "screener" })?.value == nil
            return screenerIsNil ? Color.orange : Color.gray
        } else {
            return Color.cyan
        }
    }
    
    var body: some View {
        // NavigationView は ContentView 側で TabView の各タブに適用するか、
        // またはこのビュー自体が NavigationView を持つか検討。
        // ここでは、各タブが独立したナビゲーションを持つように NavigationView を含める
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
                            .background(buttonBackgroundColor)
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
                            ForEach(Array(viewModel.fetchedImages.enumerated()), id: \.offset) { index, img in
                                VStack(alignment: .topLeading) {
                                    
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.black.opacity(0.5))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                        .padding([.leading, .top], 2)
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                        .cornerRadius(8)
                                }
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
                            ForEach(Array(viewModel.safeImagesForDisplay.enumerated()), id: \\.offset) { index, img in
                                VStack(alignment: .topLeading) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.green, lineWidth: 3)
                                        )
                                    Text("\(index + 1)")
                                        .font(.caption)
                                }
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
