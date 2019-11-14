//
//  SettingsViewController.swift
//  BIO Camera
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


private var CapturingStillImageContext = 0 //### iOS < 10.0

private var LensStabilizationContext = 0 //### iOS < 10.0

let storyboard = UIStoryboard(name: "Main", bundle: nil)

//let cameraViewController: CameraViewController = storyboard.instantiateViewController(withIdentifier: "cameraViewController") as! CameraViewController

class SettingsViewController: UITableViewController, AVCapturePhotoCaptureDelegate {
    
    // Session management.
    private var sessionQueue: DispatchQueue!

    lazy var torchTo: Float = self.torchSlider?.value ?? 0.3
    lazy var torchLevel: Float = self.torchSlider?.value ?? 0.3
    lazy var getTorchLevel: Float = self.torchSlider?.value ?? 0.3
 
    var getZoomLevel = CGFloat()
    lazy var zoomTo : Double = self.zoomFactorSwitch?.value ?? 2.0
    var videoZoomFactor = CGFloat()
    var zoomFactor = CGFloat()
    
    var cameraViewController : CameraViewController!
    
    var audioPlayer = AVAudioPlayer()

    @IBOutlet var settingsTableView: UITableView!
    
   
    @IBOutlet weak var zoomFactorLabel: UILabel!
    @IBOutlet weak var zoomFactorValue: UILabel!
    @IBOutlet weak var zoomFactorSwitch: UIStepper!
    
    @IBOutlet weak var torchLabel: UILabel!
    @IBOutlet weak var torchValue: UILabel!
    @IBOutlet weak var torchSlider: UISlider!
    
    @IBOutlet weak var autoFocusLabel: UILabel!
    @IBOutlet weak var autoFocusSwitch: UISwitch!
    
    @IBOutlet weak var continuousFocusLabel: UILabel!
    @IBOutlet weak var continuousFocusValue: UILabel!
    @IBOutlet weak var continuousFocusSlider: UISlider!
    
    @IBOutlet weak var exposureDurationLabel: UILabel!
    @IBOutlet weak var exposureDurationValue: UILabel!
    @IBOutlet weak var exposureDurationSlider: UISlider!

    @IBOutlet weak var isoLabel: UILabel!
    @IBOutlet weak var isoValue: UILabel!
    @IBOutlet weak var isoSlider: UISlider!
    
    @IBOutlet weak var colorTemperatureLabel: UILabel!
    @IBOutlet weak var colorTemperatureValue: UILabel!
    @IBOutlet weak var colorTemperatureSlider: UISlider!

    private var focusModes: [AVCaptureDevice.FocusMode] = []

    let backCamera = CameraViewController().backCamera
    
    let captureDevice = AVCaptureDevice.default(for: .video)
    
   func reset() {

        let cameraViewController = CameraViewController()
           do {
                try captureDevice?.lockForConfiguration()

                captureDevice?.isFocusModeSupported(.continuousAutoFocus)
                captureDevice?.focusMode = .continuousAutoFocus
                autoFocusSwitch.setOn(true, animated: true)

                continuousFocusSlider.value = 0.5
                let focusValue = continuousFocusSlider.value
                let newValue = Int(focusValue * 100.0)
                let rounValue = Double(newValue) / 100.0
                continuousFocusValue.text = "\(rounValue)"

                zoomFactorSwitch.value = 2.0
                zoomTo = Double(zoomFactorSwitch.value)
                cameraViewController.finalZoomLevel = CGFloat(zoomTo)
                zoomFactorValue.text = Int(zoomFactorSwitch.value).description

                torchTo = 0.3
                torchSlider.value = 0.3
                let currentValue = torchSlider.value
                let intValue = Int(currentValue * 100.0)
                let roundedValue = Double(intValue) / 100.0
                torchValue.text = "\(roundedValue)"

                self.backCamera!.setExposureModeCustom(duration: CMTimeMakeWithSeconds(0.05, preferredTimescale: 1000*1000*1000), iso: Float(180), completionHandler: nil)
                exposureDurationSlider.value = 0.05
                let initialValue = exposureDurationSlider.value
                let integerValue = Int(initialValue * 100.0)
                let roundValue = Double(integerValue) / 100.0
                exposureDurationValue.text = "\(roundValue)"

                self.backCamera!.setExposureModeCustom(duration: CMTimeMakeWithSeconds(0.015, preferredTimescale: 1000*1000*1000), iso: Float(180), completionHandler: nil)
                isoSlider.value = 180
                let firstValue = isoSlider.value
                let nextValue = Int(firstValue * 100.0)
                let rValue = Double(nextValue) / 100.0
                isoValue.text = "\(Int(rValue))"

                self.colorTemperatureSlider.value = 3500
                let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                   temperature: self.colorTemperatureSlider.value,
                    tint: 0)
                self.setWhiteBalanceGains(self.backCamera!.deviceWhiteBalanceGains(for: temperatureAndTint))
                let fValue = colorTemperatureSlider.value
                let nValue = Int(fValue * 100.0)
                let roValue = Double(nValue) / 100.0
                colorTemperatureValue.text = "\(Int(roValue))"

            } catch {
            }
    }
            
    @IBAction func defaultSettings(_ sender: UIBarButtonItem) {
        reset()
    }
           
    // Camera Settings ViewController to Camera ViewController Segue
    @IBAction func toCamera(_ sender: Any) {
        
        do {
            try backCamera?.lockForConfiguration()
            defer { backCamera?.unlockForConfiguration() }
        backCamera?.torchMode = AVCaptureDevice.TorchMode.on
        self.torchTo = torchSlider.value

        self.zoomTo = Double(zoomFactorSwitch.value)
        } catch  {
        }

        print("zoomToPre = ", zoomTo)
        print("torchToPre = ", torchTo, getTorchLevel, torchLevel)
 
    performSegue(withIdentifier: "toCamera", sender: self)
        return
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        do {
        try backCamera?.lockForConfiguration()
        defer { backCamera?.unlockForConfiguration() }

        let vc = segue.destination as! CameraViewController
        backCamera?.torchMode = AVCaptureDevice.TorchMode.on
            if torchTo == 0.000000 {
                vc.finalTorchLevel = 0.3
            }
             else {
                vc.finalTorchLevel = Float(torchTo)
            }
        vc.zoomTo = zoomTo
            if zoomTo == 0.000000 {
                vc.finalZoomLevel = 2.0
            }
             else {
                vc.finalZoomLevel = CGFloat(zoomFactorSwitch.value)
            }
        //vc.finalZoomLevel = CGFloat(zoomTo)
        //vc.finalTorchLevel = Float(torchTo)
        print("pre segue finalTorchLevel = ", vc.finalTorchLevel)
        print("pre segue finalZoomLevel = ", vc.finalZoomLevel)
        } catch  {
        }
       
    }
    
    @IBAction func returnToSettingsViewController(_ sender: Any) {
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    @IBAction func zoomStepperValueChanged(_ sender: UIStepper) {
        let device = AVCaptureDevice.default(for: .video)

        do {
            try device?.lockForConfiguration()
            
            self.zoomFactorSwitch.minimumValue = 1
            self.zoomFactorSwitch.maximumValue = 10
            zoomFactorValue.text = Int(zoomFactorSwitch.value).description
            // Check if desiredZoomFactor fits required range from 1.0 to activeFormat.videoMaxZoomFactor
            videoZoomFactor = max(1.0, min(CGFloat(zoomFactorSwitch.value), (device?.activeFormat.videoMaxZoomFactor)!))

        } catch {
        }
        device?.videoZoomFactor = CGFloat(zoomFactorSwitch.value)
        zoomTo = Double(videoZoomFactor)
            device?.unlockForConfiguration()
    }
    
    @IBAction func torchSliderValueChanged(_ sender: UISlider) {
        do {
            try self.backCamera?.lockForConfiguration()
            guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
            guard device.hasTorch else { return }

            if (device.torchMode == AVCaptureDevice.TorchMode.off) {
                device.torchMode = AVCaptureDevice.TorchMode.on
               
            }
            try backCamera?.setTorchModeOn(level: sender.value)
                do {
                    torchSlider.maximumValue = 1.0
                    torchSlider.minimumValue = 0.1
                                    
                        let currentValue = sender.value
                        let intValue = Int(currentValue * 100.0)
                        let roundedValue = Double(intValue) / 100.0
                        torchValue.text = "\(roundedValue)"
                        torchLevel = Float(roundedValue)
                        if torchLevel > 0.1 {
                                   try? backCamera?.setTorchModeOn(level: torchLevel)
                    
                        } else {
                            torchLevel = 0.3
                        }
                    try device.setTorchModeOn(level: torchSlider.value)
                    torchTo = torchLevel
                    print("torchTo value in function = ", torchTo)
                    print("torchSlider value = ", torchSlider.value)
                    print("torchLevel = ", torchLevel)
                } catch {
                    print(error)
                }
        } catch {
            print(error)
        }

            torchLevel = getTorchLevel
        self.backCamera?.unlockForConfiguration()
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
    
    @IBAction func continuousFocusSliderValueChanged(_ sender: UISlider) {
  
        let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()

        device?.setFocusModeLocked(lensPosition: sender.value)
        continuousFocusSlider.minimumValue = 0.0
        continuousFocusSlider.maximumValue = 1.0
        let currentValue = sender.value
        let intValue = Int(currentValue * 100.0)
        let roundedValue = Double(intValue) / 100.0
        continuousFocusValue.text = "\(roundedValue)"

        autoFocusSwitch.setOn(false, animated: false)
        device?.unlockForConfiguration()
        } catch {
        }
    }

    @objc let cameracontrols = cameraControls()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private var TorchLevelContext = 0
    private var ZoomFactorContext = 0
    private var CapturingStillImageContext = 0 //### iOS < 10.0
    private var ExposureModeContext = 0
    private var WhiteBalanceModeContext = 0
    private var ExposureDurationContext = 0
    private var ISOContext = 0
    private var DeviceWhiteBalanceGainsContext = 0
    private let kExposureDurationPower = 5.0 // Higher numbers will give the slider more sensitivity at shorter durations
    private let kExposureMinimumDuration = 1.0/1000 // Limit exposure duration to a useful range
    
    private var exposureModes: [AVCaptureDevice.ExposureMode] = []
  
    private func set(_ Switch: UISwitch, highlight color: UIColor) {
        Switch.tintColor = color
        if Switch === self.autoFocusSwitch {
        self.autoFocusLabel.textColor = Switch.tintColor
        }
    }
    
    private func set(_ stepper: UIStepper, highlight color: UIColor) {
           stepper.tintColor = color
           if stepper === self.zoomFactorSwitch {
            self.zoomFactorLabel.textColor = stepper.tintColor
            self.zoomFactorValue.textColor = stepper.tintColor
           }
       }
    
    private func set(_ slider: UISlider, highlight color: UIColor) {
        slider.tintColor = color
        
        if slider === self.continuousFocusSlider {
            self.continuousFocusLabel.textColor = slider.tintColor
            self.continuousFocusValue.textColor = slider.tintColor
         } else if slider === self.exposureDurationSlider {
            self.exposureDurationLabel.textColor = slider.tintColor
            self.exposureDurationValue.textColor = slider.tintColor
        } else if slider === self.torchSlider {
            self.torchLabel.textColor = slider.tintColor
            self.torchValue.textColor = slider.tintColor
        } else if slider === self.isoSlider {
            self.isoLabel.textColor = slider.tintColor
            self.isoValue.textColor = slider.tintColor
        } else if slider === self.colorTemperatureSlider {
            self.colorTemperatureLabel.textColor = slider.tintColor
            self.colorTemperatureValue.textColor = slider.tintColor
        }
    }
    
    @IBAction func switchTouchBegan(_ Switch: UISwitch) {
        self.set(Switch, highlight: UIColor.darkGray)
    }
    
    @IBAction func switchTouchEnded(_ Switch: UISwitch) {
        self.set(Switch, highlight: UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0))
    }
    
    @IBAction func stepperTouchBegan(_ stepper: UIStepper) {
           self.set(stepper, highlight: UIColor.darkGray)
     
       }
       
    @IBAction func stepperTouchEnded(_ stepper: UIStepper) {
        self.set(stepper, highlight: UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0))
       }
    
    @IBAction func sliderTouchBegan(_ slider: UISlider) {
        self.set(slider, highlight: UIColor.darkGray)
    }
    
    @IBAction func sliderTouchEnded(_ slider: UISlider) {
        self.set(slider, highlight: UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0))
    }
    
    @IBAction func exposureDurationValueChanged(_ control: UISlider) {

        let p = pow(Double(control.value), kExposureDurationPower) // Apply power function to expand slider's low-end range
        let minDurationSeconds = 0.0075 //max(CMTimeGetSeconds(self.backCamera!.activeFormat.minExposureDuration), self.kExposureMinimumDuration)
        let maxDurationSeconds = 0.333 //CMTimeGetSeconds(self.backCamera!.activeFormat.maxExposureDuration)
        let newDurationSeconds = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
       
        do {
            try self.backCamera!.lockForConfiguration()
                
            self.backCamera!.setExposureModeCustom(duration: CMTimeMakeWithSeconds(newDurationSeconds, preferredTimescale: 1000*1000*1000),  iso: AVCaptureDevice.currentISO, completionHandler: nil)

            self.backCamera!.unlockForConfiguration()
        } catch let error {
            NSLog("Could not lock device for configuration: \(error)")
            }
        let roundedValue = Double(round(10000*newDurationSeconds)/10000)
        
        self.exposureDurationValue.text = "\(roundedValue)"
      }

    
    @IBAction func isoValueChanged(_ control: UISlider) {

        do {
            try self.backCamera!.lockForConfiguration()
            
            self.backCamera!.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: control.value, completionHandler: nil)
            self.backCamera!.unlockForConfiguration()
        } catch let error {
          NSLog("Could not lock device for configuration: \(error)")
        }
        let currentValue = Int(isoSlider.value)
        isoValue.text = "\(currentValue)"
    }
    
    private func normalizedGains(_ gains: AVCaptureDevice.WhiteBalanceGains) -> AVCaptureDevice.WhiteBalanceGains {
        var g = gains
         let backCamera = CameraViewController().backCamera
        g.redGain = max(1.0, g.redGain)
        g.greenGain = max(1.0, g.greenGain)
        g.blueGain = max(1.0, g.blueGain)
        
        g.redGain = min(backCamera!.maxWhiteBalanceGain, g.redGain)
        g.greenGain = min(backCamera!.maxWhiteBalanceGain, g.greenGain)
        g.blueGain = min(backCamera!.maxWhiteBalanceGain, g.blueGain)
        return g
    }

     private func setWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains) {
           
       do {
           try self.backCamera!.lockForConfiguration()
           let normalizedGains = self.normalizedGains(gains) // Conversion can yield out-of-bound values, cap to limits
        
           self.backCamera!.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
           self.backCamera!.unlockForConfiguration()
       } catch let error {
           NSLog("Could not lock device for configuration: \(error)")
       }
        //print("normalized gains = ", normalizedGains(gains))
    }

    @IBAction func colorTemperatureChanged(_ control: UISlider) {

        func  setColorTemperatureRange() {

            self.colorTemperatureSlider.minimumValue = 2000
            self.colorTemperatureSlider.maximumValue = 9000
        }

         do {
             try self.backCamera!.lockForConfiguration()
             self.colorTemperatureSlider.value = control.value
             let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: self.colorTemperatureSlider.value,
                 tint: 0
             )
             self.setWhiteBalanceGains(self.backCamera!.deviceWhiteBalanceGains(for: temperatureAndTint))
         
         let currentValue = Int(control.value)
         colorTemperatureValue.text = "\(currentValue)"
         self.backCamera!.unlockForConfiguration()
         } catch let error {
            NSLog("Could not lock device for configuration: \(error)")
        }
        print("Color Temperature = ", colorTemperatureValue.text as Any)
    }
}

class cameraControls : NSObject {
    
    @objc dynamic var zoomFactorSwitch = 2
    @objc dynamic var torchSlider = 0.3
    @objc dynamic var exposureDurationSlider = 0.05
    @objc dynamic var isoSlider = 180
    @objc dynamic var colorTemperatureSlider = 3500
    @objc dynamic var whiteBalanceGains = 1
    
    func zoomFactorObserve() {
        var zoomFactorObservationToken: NSKeyValueObservation?

        func willSet() { willChangeValue(forKey: #keyPath(zoomFactorSwitch)) }
        
        func didSet() { didChangeValue(for: \cameraControls.zoomFactorSwitch) }
    }
    
    func torchSliderObserve() {
        var torchSlidernObservationToken: NSKeyValueObservation?

        func willSet() { willChangeValue(forKey: #keyPath(torchSlider)) }
        
        func didSet() { didChangeValue(for: \cameraControls.torchSlider) }
    }
    
    func exposureDurationObserve() {
        var exposureDurationObservationToken: NSKeyValueObservation?

        func willSet() { willChangeValue(forKey: #keyPath(exposureDurationSlider)) }
        
        func didSet() { didChangeValue(for: \cameraControls.exposureDurationSlider) }
    }
    
    func isoObserve() {
        var isoObservationToken: NSKeyValueObservation?

        func willSet() { willChangeValue(forKey: #keyPath(isoSlider)) }
        
        func didSet() { didChangeValue(for: \cameraControls.isoSlider) }
    }
    
    func whiteBalanceGainsObserve() {
        var whiteBalanceGainsObservationToken: NSKeyValueObservation?
           
       func willSet() { willChangeValue(forKey: #keyPath(whiteBalanceGains)) }
       
       func didSet()  { didChangeValue(for: \cameraControls.whiteBalanceGains) }
    }
    
    func colorTemperatureObserve() {
        var colorTemperatureObservationToken: NSKeyValueObservation?
    
           func willSet() { willChangeValue(forKey: #keyPath(colorTemperatureSlider)) }
           
           func didSet() { didChangeValue(for: \cameraControls.colorTemperatureSlider) }
    }
}

class cameraControlsObservers: NSObject {
    
    var settingsViewController = SettingsViewController()
    var zoomFactorObservationToken: NSKeyValueObservation?
    var torchSliderObservationToken: NSKeyValueObservation?
    var exposureDurationObservationToken: NSKeyValueObservation?
    var exposureTargetBiasObservationToken: NSKeyValueObservation?
    var exposureTargetOffsetObservationToken: NSKeyValueObservation?
    var isoObservationToken: NSKeyValueObservation?
    var colorTemperatureObservationToken: NSKeyValueObservation?
    var tintObservationToken: NSKeyValueObservation?
    var whiteBalanceModeObservationToken: NSKeyValueObservation?
    var whiteBalanceGainsObservationToken: NSKeyValueObservation?
    
    @objc  var cameracontrols: cameraControls
    var observation: NSKeyValueObservation?
    
    init(object: cameraControls) {
        self.cameracontrols = object
        super.init()

        let zoomFactorValue = SettingsViewController().zoomFactorValue
            observation = observe(\.cameracontrols.zoomFactorSwitch,
                                  options: [.initial, .old, .new], changeHandler: {
                                    (object, change) in
                print(change.newValue ?? "")
                
                                    let currentValue = change.newValue
                                    let intValue = Int(Double(currentValue!) * 100.0)
                                    let roundedValue = Double(intValue) / 100.0
                                    zoomFactorValue?.text = "\(roundedValue)"

        })
        
        let torchValue = SettingsViewController().torchValue
               observation = observe(\.cameracontrols.torchSlider,
                                     options: [.initial, .old, .new], changeHandler: {
                                       (object, change) in
                   print(change.newValue ?? "")
                   
                                       let currentValue = change.newValue
                                       let intValue = Int(Double(currentValue!) * 100.0)
                                       let roundedValue = Double(intValue) / 100.0
                                       torchValue?.text = "\(roundedValue)"

           })
        
        let exposureDurationValue = SettingsViewController().exposureDurationValue
        observation = observe(\.cameracontrols.exposureDurationSlider,
                              options: [.initial, .old, .new], changeHandler: {
                                (object, change) in
            print(change.newValue ?? "")
            
                                let currentValue = change.newValue
                                let intValue = Int(Double(currentValue!) * 100.0)
                                let roundedValue = Double(intValue) / 100.0
                                exposureDurationValue?.text = "\(roundedValue)"

    })
        

        let isoValue = SettingsViewController().isoValue
                     observation = observe(\.cameracontrols.isoSlider,
                                           options: [.initial, .old, .new], changeHandler: {
                                             (object, change) in
                         print(change.newValue ?? "")
                         
                                             let currentValue = change.newValue
                                             let intValue = Int(Double(currentValue!) * 100.0)
                                             let roundedValue = Double(intValue) / 100.0
                                             isoValue?.text = "\(roundedValue)"

    })
        
        let colorTemperatureValue = SettingsViewController().colorTemperatureValue
                     observation = observe(\.cameracontrols.colorTemperatureSlider,
                                           options: [.initial, .old, .new], changeHandler: {
                                             (object, change) in
                         print(change.newValue ?? "")
                         
                                             let currentValue = change.newValue
                                             let intValue = Int(Double(currentValue!) * 100.0)
                                             let roundedValue = Double(intValue) / 100.0
                                             colorTemperatureValue?.text = "\(roundedValue)"

    })
    }
}
    
extension NSObject {
  func safeRemoveObserver(_ observer: NSObject, forKeyPath keyPath: String) {
    switch self.observationInfo {
    case .some:
      self.removeObserver(observer, forKeyPath: keyPath)
    default:
      debugPrint("observer does no not exist")
    }
  }
}

