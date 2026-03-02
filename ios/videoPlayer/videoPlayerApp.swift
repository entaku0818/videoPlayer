//
//  videoPlayerApp.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import SwiftUI
import FirebaseCore
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
   func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
       FirebaseApp.configure()

       do {
           try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
           try AVAudioSession.sharedInstance().setActive(true)
       } catch {
           print("[AudioSession] Failed to configure: \(error)")
       }

       return true
   }
}



@main
struct videoPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
