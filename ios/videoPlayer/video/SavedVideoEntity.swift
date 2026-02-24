//
//  SavedVideoEntity.swift
//  videoPlayer
//
//  Created by 遠藤拓弥 on 2024/12/01.
//

import Foundation
struct SavedVideoEntity: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let title: String
    let duration: Double
    let createdAt: Date
    let lastPlaybackPosition: Double
    let lastPlayedAt: Date?
    let sourceURL: String?
    let videoType: String?

    var isLocalVideo: Bool { videoType == nil || videoType == "local" }

    // 再生進捗（0.0〜1.0）
    var playbackProgress: Double {
        guard duration > 0 else { return 0 }
        return lastPlaybackPosition / duration
    }

    // 続きから再生可能か（5秒以上再生していて、95%未満の場合）
    var canResumePlayback: Bool {
        lastPlaybackPosition > 5 && playbackProgress < 0.95
    }
}
