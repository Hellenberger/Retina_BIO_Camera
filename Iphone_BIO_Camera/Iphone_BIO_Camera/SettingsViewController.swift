//
//  SettingsViewController.swift
//  Iphone_BIO_Camera
//
//  Created by Howard Ellenberger on 9/4/19.
//  Copyright © 2019 Howard Ellenberger. All rights reserved.
//

import Foundation

import UIKit
import CoreAudio
import MediaPlayer
import AVFoundation
import Photos
import AudioToolbox

class SettingsViewController: UITableViewController, AVCapturePhotoCaptureDelegate {
    
    var torchLevel = Float()
    var getTorchLevel = Float(0.50)
    var newTorchLevel = Float()
    
    var changeZoomLevel = CGFloat()
    var cameraViewController : CameraViewController!
    
    let backCamera = CameraViewController().backCamera!
    
    var audioPlayer = AVAudioPlayer()

    @IBOutlet weak var lensPositionSlider: UISlider!
    
    @IBOutlet weak var lensPositionValueLabel: UILabel!
    
    @IBOutlet weak var torchSlider: UISlider!

    @IBOutlet weak var sliderValue: UILabel!

    @IBOutlet weak var zoomStepper: UIStepper!

    @IBOutlet weak var zoomLevel: UILabel!
    
    private var focusModes: [AVCaptureDevice.FocusMode] = []

    
    @IBAction func lensPositionSliderValueChanged(_ sender: UISlider) {
    
        let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()
            
            try device?.setFocusModeLocked(lensPosition: sender.value)
        } catch {
        }
        
        self.lensPositionSlider.minimumValue = 0.0
        self.lensPositionSlider.maximumValue = 1.0
        let currentValue = sender.value
        let intValue = Int(currentValue * 100.0)
        let roundedValue = Double(intValue) / 100.0
        lensPositionValueLabel.text = "\(roundedValue)"
        device?.unlockForConfiguration()
    }
    
    @IBAction func autoFocus(_ sender: UISwitch) {
    
        let captureDevice = AVCaptureDevice.default(for: .video)
        do {
            try captureDevice?.lockForConfiguration()
            
        } catch {
        }
        captureDevice?.isFocusModeSupported(.continuousAutoFocus)
        captureDevice?.focusMode = .continuousAutoFocus
        captureDevice?.unlockForConfiguration()
    }

    @IBAction func stepperValueChanged(_ sender: UIStepper) {
 
       let backCamera = CameraViewController().backCamera

        do {
            try backCamera?.lockForConfiguration()
            
        } catch {
        }
        
        zoomLevel.text = Int(sender.value).description

            self.zoomStepper.minimumValue = 1
            self.zoomStepper.maximumValue = 10
            let zoomFactor = zoomStepper.value
            backCamera?.videoZoomFactor = CGFloat(zoomFactor)
            backCamera?.unlockForConfiguration()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        zoomStepper.wraps = true
        zoomStepper.autorepeat = true
        zoomStepper.maximumValue = 10
    }

    @IBAction func sliderValueChanged(_ sender: UISlider!) {
        
           let backCamera = CameraViewController().backCamera
            do {
                try backCamera?.lockForConfiguration()
            } catch {
            }
            do {
                try backCamera?.setTorchModeOn(level: sender.value)
            } catch {
            }

            torchSlider.maximumValue = 1.0
            torchSlider.minimumValue = 0.1
        
            let currentValue = sender.value
            let intValue = Int(currentValue * 100.0)
            let roundedValue = Double(intValue) / 100.0
            sliderValue.text = "\(roundedValue)"
        if currentValue == Float(0.0) { return }
        else {
        self.getTorchLevel = currentValue
        }
        
        backCamera?.unlockForConfiguration()
        print("torch level = ", getTorchLevel)
    }
    
    // Camera Settings ViewController to Camera ViewController Segue
    @IBAction func toCamera(_ sender: Any) {
        
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        
        guard let cameraViewController = mainStoryboard.instantiateViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
            print("Couldn't find Camera ViewController")
            return
        }
        navigationController?.pushViewController(cameraViewController, animated: true)
        self.changeZoomLevel = (backCamera.videoZoomFactor)
        cameraViewController.zoomTo = changeZoomLevel
        
        cameraViewController.torchTo = getTorchLevel
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}
