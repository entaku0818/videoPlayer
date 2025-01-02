//
//  videoPlayerApp.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import SwiftUI
import FirebaseAnalytics
import os.log
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "videoPlayer", category: "Main")

   func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
       FirebaseApp.configure()

       if FirebaseApp.app() != nil {
           logger.info("Firebase initialized successfully")
       } else {
           logger.error("Firebase initialization failed")
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
