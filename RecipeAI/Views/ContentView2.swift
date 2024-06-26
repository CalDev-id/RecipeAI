//
//  ContentView.swift
//  RecipeAI
//
//  Created by Heical Chandra on 29/05/24.
//

import SwiftUI
import Vision
import CoreML
import GoogleGenerativeAI


struct ContentView: View {
    @State private var isImagePickerPresented: Bool = false
    @State private var showResultSheet: Bool = false
    @State private var detectedObjects: [Observation] = []
    let model = try! YOLOv3Tiny(configuration: MLModelConfiguration())
    
    let cameraService = CameraService()
    @Binding var capturedImage: UIImage?
    
    var body: some View {
        VStack {
            Text("PHOTO A INGREDIENTS")
                .font(.title3)
            Button("Take a Picture") {
                isImagePickerPresented.toggle()
            }
                .sheet(isPresented: $isImagePickerPresented, onDismiss: loadImage) {
//                ImagePicker(image: self.$capturedImage)
                    ZStack {
                        CameraView(cameraService: cameraService) { result in
                            switch result {
                            case .success(let photo):
            
                                if let data = photo.fileDataRepresentation() {
            
                                    Task {
                                        do {
                                            capturedImage = UIImage(data: data)
                                        } catch {
                                            print("Error: \(error)")
                                        }
                                    }
//                                    capturedImage = UIImage(data: data)
                                } else {
                                    print("Error: no image data found")
                                }
                            case .failure(let err):
                                print(err.localizedDescription)
                            }
                        }
                        
                        
                        VStack {
                            Spacer()
                            Button(action: {
                                cameraService.capturePhoto()
                                isImagePickerPresented.toggle()
                            }, label: {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 72))
                                    .foregroundColor(.white)
                            })
                            .padding(.bottom)
                        }
                        VStack{
                            Spacer().frame(maxHeight: 200)
                            Text("Foto bahan makanan")
                            Spacer()
                        }
                    }
                    .ignoresSafeArea()
            }
                .sheet(isPresented: $showResultSheet, onDismiss: {capturedImage = nil; print("auy")}) {
                    ResultView(capturedImage: $capturedImage, detectedObjects: $detectedObjects, showResultSheet: $showResultSheet)
            }
        }
    }
    func loadImage() {
        let mlModel = model.model
        guard let vnCoreMLModel = try? VNCoreMLModel(for: mlModel) else { return }
        let request = VNCoreMLRequest(model: vnCoreMLModel) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
            detectedObjects = results.map { result in
                guard let label = result.labels.first?.identifier else { return Observation(label: "", confidence: VNConfidence.zero, boundingBox: .zero) }
                let confidence = result.labels.first?.confidence ?? 0.0
                let boundedBox = result.boundingBox
                let observation: Observation = Observation(label: label, confidence: confidence, boundingBox: boundedBox)
                return observation
            }
            print(detectedObjects)
        }
        guard let image = capturedImage, let pixelBuffer = convertToCVPixelBuffer(newImage: image) else {
            return
        }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        do {
            try requestHandler.perform([request])
            showResultSheet.toggle()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
struct Observation {
    let label: String
    let confidence: VNConfidence
    let boundingBox: CGRect
}


func convertToCVPixelBuffer(newImage: UIImage) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)

    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

    context?.translateBy(x: 0, y: newImage.size.height)
    context?.scaleBy(x: 1.0, y: -1.0)

    UIGraphicsPushContext(context!)
    newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    return pixelBuffer
}

struct ResultView: View {
    @Binding var capturedImage:UIImage?
    @Binding var detectedObjects: [Observation]
    @Binding var showResultSheet: Bool
    @State private var item_food: [String] = []
    @State private var prompt = ""
    @State private var response = ""
  //    let model = GenerativeModel(name: "gemini-pro-vision", apiKey: APIKey.default)
      let model = GenerativeModel(name: "gemini-pro", apiKey: APIKey.default)
    
    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
                    .overlay {
                        GeometryReader { geometry in
                            Path { path in
                                for observation in detectedObjects {
                                    path.addRect(VNImageRectForNormalizedRect(observation.boundingBox, Int(geometry.size.width), Int(geometry.size.height)))
                                }
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                        }
                    }
            }
            if !detectedObjects.isEmpty {
                VStack {
                    List(detectedObjects, id: \.label) { item in
                        HStack {
                            Text(item.label.capitalized)
                            Spacer()
                            Text("\(item.confidence * 100, specifier: "%.2f")%")
                        }
                        .onAppear {
                            item_food = detectedObjects.map { $0.label }
                            print(item_food)
                            updatePrompt()
                            Task {
                              // Generate text from the prompt
                              do {
                                let response = try! await model.generateContent(prompt)
                                self.response = response.text ?? ""
                              } catch {
                                print(error.localizedDescription)
                              }
                            }
                        }
                        
                        
                    }
//                    Button("Rekomendasi Resep") {
//                      Task {
//                        // Generate text from the prompt
//                        do {
//                          let response = try! await model.generateContent(prompt)
//                          self.response = response.text ?? ""
//                        } catch {
//                          print(error.localizedDescription)
//                        }
//                      }
//                    }
                    Text(response)
                }
            } else {
                VStack {
                    Text("Nothing could be detected.")
                    Button("Try again!") {
                        capturedImage = nil
                        detectedObjects = []
                        showResultSheet.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
//        .onAppear(perform: {
//
//        })
        .padding(.all)
    }
    private func updatePrompt() {
        prompt = "rekomendasikan saya resep makanan berbahan \(item_food.joined(separator: ", "))"
    }
}
