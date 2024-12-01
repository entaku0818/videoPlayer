//
//  Filea.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
struct SavedVideoEntity: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let title: String
    let duration: Double
    let createdAt: Date
}
