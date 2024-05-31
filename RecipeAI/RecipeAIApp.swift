//
//  RecipeAIApp.swift
//  RecipeAI
//
//  Created by Heical Chandra on 29/05/24.
//

import SwiftUI

@main
struct RecipeAIApp: App {
    @State private var capturedImage: UIImage? = nil

    var body: some Scene {
        WindowGroup {
            ContentView(capturedImage: $capturedImage)
        }
    }
}
