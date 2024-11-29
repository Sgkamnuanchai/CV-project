import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedImage: UIImage? = nil
    @State private var isCameraPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var resultText: String = "No result yet"
    @State private var isCalculateButtonVisible = false
    @State private var showNutritionPopup = false
    @State private var nutritionInfo = "Loading..."
    @State private var classFood: String = ""
    @State private var isLoading: Bool = false
    @State private var showReference: Bool = true
    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .border(Color.gray, width: 1)
                
                // แสดงผลลัพธ์ใต้รูปภาพ
                Text(resultText)
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
            } else {
                Text("No image selected")
                    .foregroundColor(.gray)
            }
            
            if isLoading {
                            ProgressView("Processing...") // Loading Indicator
                                .padding()
                        }

            Spacer()

            Button(action: {
                showReference = false
                isCameraPresented = true
            }) {
                Label("Take Photo", systemImage: "camera")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .sheet(isPresented: $isCameraPresented) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            
                            uploadImage(image: image, isLoading: $isLoading) { className, confidence in
                                DispatchQueue.main.async {
                                    if let className = className, let confidence = confidence {
                                        let formattedClassName = className.replacingOccurrences(of: "_", with: " ")
                                                                                resultText = "Image: \(formattedClassName)\nConfidence: \(String(format: "%.2f", confidence * 100))%"
                                        classFood = "\(formattedClassName)"
                                        isCalculateButtonVisible = true
                                    } else {
                                        resultText = "Failed to get result"
                                        isCalculateButtonVisible = false
                                    }
                                }
                            }
                        }
                    }
            }

            Button(action: {
                showReference = false
                isPhotoPickerPresented = true
            }) {
                Label("Upload Photo", systemImage: "photo.on.rectangle")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .sheet(isPresented: $isPhotoPickerPresented) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                           
                            uploadImage(image: image,isLoading: $isLoading) { className, confidence in
                                DispatchQueue.main.async {
                                    if let className = className, let confidence = confidence {
                                        let formattedClassName = className.replacingOccurrences(of: "_", with: " ")
                                                                                resultText = "Image: \(formattedClassName)\nConfidence: \(String(format: "%.2f", confidence * 100))%"
                                        classFood = "\(formattedClassName)"
                                        isCalculateButtonVisible = true
                                    } else {
                                        resultText = "Failed to get result"
                                        isCalculateButtonVisible = false
                                    }
                                }
                            }
                        }
                    }
            }
            if isCalculateButtonVisible {
                            Button(action: {
                               
                                fetchNutrition(for: resultText,classFood: classFood, isLoading: $isLoading) { nutritionData in
                                    DispatchQueue.main.async {
                                        self.nutritionInfo = nutritionData
                                        self.showNutritionPopup = true
                                    }
                                }
                            }) {
                                Label("Calculate", systemImage: "chart.bar")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding()
                            .alert("Nutrition Information", isPresented: $showNutritionPopup) {
                                Button("OK", role: .cancel) { }
                            } message: {
                                Text(nutritionInfo)
                            }
            }
        }
        .padding()
        
        // Reference text at the bottom-right corner
        if showReference {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("SnapNourish: A Food and Nutrition Recognition App\nSubmitted to Dr. Cherdsak Kingkan\nAT82.08: Computer Vision August 2024")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.trailing)
                                        .padding(8)
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottomTrailing)
                            }
                        }
                    }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

func uploadImage(image: UIImage, isLoading: Binding<Bool>, completion: @escaping (String?, Double?) -> Void) {
    
    DispatchQueue.main.async {
            isLoading.wrappedValue = true
        }
    guard let url = URL(string: "http://192.168.2.35:8000/predict/") else {
        completion(nil, nil)
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    let body = NSMutableData()
    let imageData = image.jpegData(compressionQuality: 0.8)!
    
    body.appendString("--\(boundary)\r\n")
    body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
    body.appendString("Content-Type: image/jpeg\r\n\r\n")
    body.append(imageData)
    body.appendString("\r\n")
    body.appendString("--\(boundary)--\r\n")
    
    request.httpBody = body as Data
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
                    isLoading.wrappedValue = false // หยุด Loading
                }
        guard let data = data, error == nil else {
            print("Error: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil, nil)
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let className = result["class_name"] as? String,
               let confidence = result["confidence"] as? Double {
                completion(className, confidence)
            } else {
                completion(nil, nil)
            }
        } catch {
            print("Error parsing JSON: \(error.localizedDescription)")
            completion(nil, nil)
        }
    }.resume()
}

func fetchNutrition(for resultText: String, classFood: String, isLoading: Binding<Bool>, completion: @escaping (String) -> Void) {
    DispatchQueue.main.async {
                isLoading.wrappedValue = false
            }
    guard let url = URL(string: "https://api.edamam.com/api/food-database/v2/parser?app_id=a7d8c450&app_key=c804884912c5b377ae54a1dc8060f4d9&ingr=\(classFood)") else {
        completion("Invalid URL")
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, error == nil else {
            completion("Failed to fetch nutrition data")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let hints = json["hints"] as? [[String: Any]] {
                
                var maxCaloriesHint: [String: Any]? = nil
                var maxCalories: Double = 0.0
                
                // วนลูปเพื่อหาค่าที่ ENERC_KCAL มากที่สุด
                for hint in hints {
                    if let food = hint["food"] as? [String: Any],
                       let nutrients = food["nutrients"] as? [String: Double],
                       let calories = nutrients["ENERC_KCAL"] {
                        
                        if calories > maxCalories {
                            maxCalories = calories
                            maxCaloriesHint = food
                        }
                    }
                }
                
                // แสดงผลลัพธ์ของอาหารที่มีแคลอรีสูงสุด
                if let maxHint = maxCaloriesHint {
                    let name = maxHint["label"] as? String ?? "Unknown"
                    let nutrients = maxHint["nutrients"] as? [String: Double] ?? [:]
                    
                    // คำนวณ Calories Breakdown
                    let proteinCalories = (nutrients["PROCNT"] ?? 0) * 4
                    let fatCalories = (nutrients["FAT"] ?? 0) * 9
                    let carbCalories = (nutrients["CHOCDF"] ?? 0) * 4
                    let totalCalories = proteinCalories + fatCalories + carbCalories
                    
                    let result = """
                    Name: \(name)
                    Calories Breakdown:
                    - Protein Calories: \(String(format: "%.2f", proteinCalories)) cal
                    - Fat Calories: \(String(format: "%.2f", fatCalories)) cal
                    - Carbohydrate Calories: \(String(format: "%.2f", carbCalories)) cal
                    - Total Calories: \(String(format: "%.2f", totalCalories)) cal
                    """
                    
                    print(result)
                    completion(result)
                } else {
                    completion("No valid data found")
                }
                
            } else {
                completion("Failed to parse nutrition data")
            }
        } catch {
            completion("Error parsing data")
        }
    }.resume()
}





extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
