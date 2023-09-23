//
//  CameraSoundModel.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 17.10.2022.
//

import UIKit
import AVFoundation

class CameraSoundModel: NSObject, ObservableObject {
    var audioPlayer: AVAudioPlayer?
    @Published var isPlayng: Bool = false
    
     func prepareSoundClick() {
        guard let url: URL = Bundle.main.url(forResource: "camera_shutter_click", withExtension: "mp3") else {
            return
        }
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.delegate = self
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    func playSound() {
        if isPlayng {
            return
        }
        if self.audioPlayer?.play() == true {
            DispatchQueue.main.async {
                self.isPlayng.toggle()
            }
        }
    }
    
    func stopPlayer() {
        self.audioPlayer?.stop()
    }
}

extension CameraSoundModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlayng.toggle()
        }
    }
}
