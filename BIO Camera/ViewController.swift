//  ViewController.swift
//  ReplicateCameraView
//
//  Created by Howard Ellenberger on 6/19/19.
//  Copyright © 2019 Howard Ellenberger. All rights reserved.

import UIKit
import CoreAudio
import MediaPlayer
import AVFoundation
import Photos
import AudioToolbox

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    let shutterSound = Bundle.main.url(forResource: "shutter_click", withExtension: "mp3")

    var timestamp:Double!

    var audioPlayer = AVAudioPlayer()
    
    @IBOutlet weak var labelView: UIView!
    
    @IBOutlet weak var timeStamp: UILabel!
        var now = ""
 
    @IBOutlet weak var imageSaved: UILabel!
    
    @IBOutlet weak var torchSlider: UISlider!
 
    @IBOutlet weak var sliderValue: UILabel!
    
    @IBOutlet var mainView: UIView!
    
    @IBOutlet weak var cameraView: UIImageView!
    
    @IBOutlet weak var lensPositionSlider: UISlider!
    
    @IBOutlet weak var lensPositionbValueLabel: UILabel!
    
    let viewBackgroundColor : UIColor = UIColor.black
    
    var initialVolume: Float = 0.25
    var volumeView: MPVolumeView!
    var audioSession: AVAudioSession?
    var volumeUpdated: Bool = false
    
    var image: UIImage?
    var captureDevice: AVCaptureDevice?
    var session: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var photoSetting = AVCapturePhotoSettings()
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var photoOutput: AVCapturePhotoOutput?
    
    private var focusModes: [AVCaptureDevice.FocusMode] = []
    
    override var prefersStatusBarHidden: Bool { return true }

    @IBAction func autoFocus(_ sender: Any) {
        
        let captureDevice = AVCaptureDevice.default(for: .video)
        do {
            try captureDevice?.lockForConfiguration()

        } catch {
        }
        captureDevice?.isFocusModeSupported(.continuousAutoFocus)
        try! captureDevice?.lockForConfiguration()
        captureDevice?.focusMode = .continuousAutoFocus
        captureDevice?.unlockForConfiguration()
    }
    
    @IBAction func lensSliderValueChanged(_ slider: UISlider) {
        
        let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()
        
            try device?.setFocusModeLocked(lensPosition: slider.value)
        } catch {
        }
       
        self.lensPositionSlider.minimumValue = 0.0
        self.lensPositionSlider.maximumValue = 1.0
        let currentValue = slider.value
        let intValue = Int(currentValue * 100.0)
        let roundedValue = Double(intValue) / 100.0
        lensPositionbValueLabel.text = "\(roundedValue)"
        device?.unlockForConfiguration()
    }

    @IBAction func buttonPressed(_ sender: Any?) {
        setVolumeLevel(0.25)
        print(initialVolume)
        
        takePhoto ()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: shutterSound!)
            audioPlayer.play()
        } catch {
            // couldn't load file :(
        }

        captureImage {(newImage, error) in
            guard let image = newImage else {
                print(error ?? "Image capture error")
                return
            }
            let flippedImage = image.withHorizontallyFlippedOrientation()
            
            let squareImage = flippedImage.cropToSquare(image: flippedImage)
            let roundedImage = squareImage?.roundedImage()
            let newImage = roundedImage?.rotate(radians: -.pi/2) // Rotate 90 degrees

            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAsset(from: newImage!)
            }
        }
    }
}

extension ViewController {
    
    func takePhoto() {

        func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            
            guard error == nil else { print("Error capturing photo: \(error!)"); return }

            //MARK: - Save image
            func saveImage() {
                
                guard let selectedImage = cameraView.image
                    else {
                    return
                }
                UIImageWriteToSavedPhotosAlbum(selectedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
        self.imageSaved.fadeOut(completion: {
            (finished: Bool) -> Void in
            self.imageSaved.text = "Image Saved"
            self.imageSaved.fadeIn()
            self.imageSaved.fadeOut()
        })
    }
    //MARK: - Save Image callback
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        
        if let error = error {
            
            print(error.localizedDescription)
            
        } else {
            
            print("Success")
        }
    }
    
    func flashActive() {
        if let currentDevice = AVCaptureDevice.default(for: AVMediaType.video), currentDevice.hasTorch {
            do {
                try currentDevice.lockForConfiguration()
                let torchOn = !currentDevice.isTorchActive
                currentDevice.torchMode = torchOn ? .on : .off
                currentDevice.unlockForConfiguration()
            } catch {
                print("error")
                
            }
            do {
                try currentDevice.lockForConfiguration()
                try currentDevice.setTorchModeOn(level: 0.25) } catch { currentDevice.unlockForConfiguration()
            }
        }
    }
}

extension AVCaptureDevice {
    
    // MARK: - device lookup
    /// Returns the capture device for the desired device type and position.
    /// #protip, NextLevelDevicePosition.avfoundationType can provide the AVFoundation type.
    ///
    /// - Parameters:
    ///   - deviceType: Specified capture device type, (i.e. builtInMicrophone, builtInWideAngleCamera, etc.)
    ///   - position: Desired position of device
    /// - Returns: Capture device for the specified type and position, otherwise nil
    public class func captureDevice(withType deviceType: AVCaptureDevice.DeviceType, forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [deviceType]
        if let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: position).devices.first {
            return discoverySession
        }
        return nil
    }
    
    /// Returns the default wide angle video device for the desired position, otherwise nil.
    ///
    /// - Parameter position: Desired position of the device
    /// - Returns: Wide angle video capture device, otherwise nil
    public class func wideAngleVideoDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [AVCaptureDevice.DeviceType.builtInWideAngleCamera]
        if let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: position).devices.first {
            return discoverySession
        }
        return nil
    }
    
    /// Returns the default telephoto video device for the desired position, otherwise nil.
    ///
    /// - Parameter position: Desired position of the device
    /// - Returns: Telephoto video capture device, otherwise nil
    public class func telephotoVideoDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [AVCaptureDevice.DeviceType.builtInTelephotoCamera]
        if let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: position).devices.first {
            return discoverySession
        }
        return nil
    }
    
    /// Returns the primary duo camera video device, if available, else the default wide angel camera, otherwise nil.
    ///
    /// - Parameter position: Desired position of the device
    /// - Returns: Primary video capture device found, otherwise nil
    public class func primaryVideoDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [AVCaptureDevice.DeviceType.builtInDualCamera]
        if #available(iOS 11.0, *) {
            deviceTypes.append(.builtInDualCamera)
        } else {
            deviceTypes.append(.builtInDuoCamera)
        }
        
        // prioritize duo camera systems before wide angle
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: position)
        for device in discoverySession.devices {
            if #available(iOS 11.0, *) {
                if (device.deviceType == AVCaptureDevice.DeviceType.builtInDualCamera) {
                    return device
                }
            } else {
                if (device.deviceType == AVCaptureDevice.DeviceType.builtInDuoCamera) {
                    return device
                }
            }
        }
        return discoverySession.devices.first
    }
    
    /// Returns the default video capture device, otherwise nil.
    ///
    /// - Returns: Default video capture device, otherwise nil
    public class func videoDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(for: AVMediaType.video)
    }
}

extension ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setVolumeLevel(0.25)
        
        let cameraView = CALayer()
        let replicatorLayer = CAReplicatorLayer()
        let instanceCount = 2
        replicatorLayer.instanceCount = 2
        replicatorLayer.instanceCount = instanceCount
        replicatorLayer.frame = CGRect(x: 0, y: 15, width: 320, height: 320)
        replicatorLayer.instanceTransform = CATransform3DMakeTranslation(366, 0, 0)
        replicatorLayer.addSublayer(cameraView)
        self.view.layer.addSublayer(replicatorLayer)
        
        var settings = AVCapturePhotoBracketSettings()
        
        if #available(iOS 10.0, *) {
            // For iOS 10.0 +
            let center  = UNUserNotificationCenter.current()
            center.delegate = self as? UNUserNotificationCenterDelegate
            center.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in
                if error == nil{
                    DispatchQueue.main.async(execute: {
                        UIApplication.shared.registerForRemoteNotifications()
                    })
                }
            }
        }else{
            // Below iOS 10.0
            
            let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
            
            //or
            //UIApplication.shared.registerForRemoteNotifications()
        }
        
        @available(iOS 10.0, *)
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            
        }
        
        @available(iOS 10.0, *)
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            
        }
        
        
        func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            // .. Receipt of device token
        }
        
        
        func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
            // handle error
        }
        
        UIApplication.shared.unregisterForRemoteNotifications()

        
        //Camera
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if response {
                //access granted
            } else {
            }
        }
        
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.high
                
        guard let backCamera = AVCaptureDevice.videoDevice() else {
            print("No camera found")
            return
        }
        
        var error: NSError?

            do {
                // add the input
                let input = try AVCaptureDeviceInput(device: backCamera)
                if error == nil && session!.canAddInput(input) {
                    session!.addInput(input)
                    photoOutput = AVCapturePhotoOutput()
                    }
                } catch let error1 as NSError {
                    error = error1
                    print(error!.localizedDescription)
                }
        
            // Configure camera

        settings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0,
                                                 processedFormat: [AVVideoCodecKey : AVVideoCodecType.hevc])


        if photoOutput!.isStillImageStabilizationSupported{
            settings.isAutoStillImageStabilizationEnabled = true
        }
        if photoOutput!.isHighResolutionCaptureEnabled {
            settings.isHighResolutionPhotoEnabled = true
        }
            settings.isDualCameraDualPhotoDeliveryEnabled = true
            settings.isAutoDualCameraFusionEnabled = false

            if session!.canAddOutput(photoOutput!) {
                session!.addOutput(photoOutput!)
                
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session) as AVCaptureVideoPreviewLayer
                self.videoPreviewLayer?.frame.size = self.cameraView.frame.size
                self.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                self.videoPreviewLayer?.connection?.videoOrientation = .landscapeRight
                self.videoPreviewLayer.frame = self.cameraView.frame
                cameraView.addSublayer(videoPreviewLayer)
                
                do {
                    try backCamera.lockForConfiguration()
                    let zoomFactor:CGFloat = 1.0
                    backCamera.videoZoomFactor = zoomFactor
                    try backCamera.lockForConfiguration()
                    backCamera.focusMode = .autoFocus
                    backCamera.unlockForConfiguration()
                } catch {
                    //Catch error from lockForConfiguration
                }
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider!) {
        
        let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()
        } catch {
        }
        do {
            try device?.setTorchModeOn(level: sender.value)
        } catch {
        }
        device?.unlockForConfiguration()
        
        torchSlider.maximumValue = 1.0
        torchSlider.minimumValue = 0.1
        
        let currentValue = sender.value
        let intValue = Int(currentValue * 100.0)
        let roundedValue = Double(intValue) / 100.0
        sliderValue.text = "\(roundedValue)"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
        flashActive()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        
        self.videoPreviewLayer?.frame.size = self.cameraView.frame.size
    }
    
    enum CameraViewControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = session, captureSession.isRunning else { completion(nil, CameraViewControllerError.captureSessionIsMissing); return }

        let exposureValues: [Float] = [-1, 0, +1]
        let makeAutoExposureSettings = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias:)
        let exposureSettings = exposureValues.map(makeAutoExposureSettings)
        let settings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0,
                                                     processedFormat: [AVVideoCodecKey : AVVideoCodecType.hevc],
                                                     bracketedSettings:
            exposureSettings)
        
        if photoOutput!.isStillImageStabilizationSupported{
            settings.isAutoStillImageStabilizationEnabled = true
        }
        if photoOutput!.isHighResolutionCaptureEnabled {
            settings.isHighResolutionPhotoEnabled = true
        }
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        
        self.photoCaptureCompletionBlock = completion
    }
}

extension UIView {
    func fadeIn(_ duration: TimeInterval = 0.0, delay: TimeInterval = 0.0, completion: @escaping ((Bool) -> Void) = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.alpha = 1.0
            }, completion: completion)  }

    func fadeOut(_ duration: TimeInterval = 2.0, delay: TimeInterval = 0.0, completion: @escaping (Bool) -> Void = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.alpha = 0.0
            }, completion: completion)
        }
}

public extension UIImage {
    func cropToSquare(image: UIImage) -> UIImage? {
        var imageHeight = image.size.height
        var imageWidth = image.size.width
        print(imageHeight)
        print (imageWidth)
        
        if imageHeight > imageWidth {
            imageHeight = imageWidth
        }
        else {
            imageWidth = imageHeight
        }
        
        let size = CGSize(width: imageWidth, height: imageHeight)
        
        let refWidth : CGFloat = CGFloat(image.cgImage!.width)
        let refHeight : CGFloat = CGFloat(image.cgImage!.height)
        
        let x = (refWidth - size.width) / 2
        let y = (refHeight - size.height) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
        if let imageRef = image.cgImage!.cropping(to: cropRect) {
            let cropToSquare : UIImage = UIImage(cgImage: imageRef, scale: 0, orientation: image.imageOrientation)
            return cropToSquare
        }
        return nil
    }
    
    func roundedImage() -> UIImage {
        let cameraView: UIImageView = UIImageView(image: self)
        let layer = cameraView.layer
        layer.masksToBounds = true
        layer.cornerRadius = cameraView.frame.width / 2
        UIGraphicsBeginImageContext(cameraView.bounds.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return roundedImage!
    }
}

extension ViewController {
   
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        
        guard let imageData = photo.fileDataRepresentation() else { return }

        if let image = UIImage(data: imageData) {

            self.photoCaptureCompletionBlock?(image, nil)
            }
            
        else {
            self.photoCaptureCompletionBlock?(nil, CameraViewControllerError.unknown)
        }
    }
}

public extension UIImage {
    
    func rotate(radians: Float) -> UIImage? {
        

        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        //let timeStamp : UILabel
        UIGraphicsBeginImageContext(rotatedImage!.size)
            
        rotatedImage!.draw(in: CGRect(x: 20, y: 0, width: rotatedImage!.size.width, height: rotatedImage!.size.height))
        
        //draw label        
        let labelRect = CGRect(x: 50, y: 50, width: rotatedImage!.size.width - 100, height: rotatedImage!.size.height / 16)
        
        let timeStamp = UILabel(frame: labelRect)
        
        let dateformatter = DateFormatter()
        
        dateformatter.dateStyle = DateFormatter.Style.long
        
        dateformatter.timeStyle = DateFormatter.Style.medium
        
        let now = dateformatter.string(from: Date())
        
        print(now)
        timeStamp.backgroundColor = UIColor.clear
        timeStamp.textAlignment = .center
        timeStamp.textColor = UIColor.darkGray
        timeStamp.shadowColor = UIColor.white
        timeStamp.shadowOffset = CGSize(width: 2, height: 2)
        timeStamp.font = UIFont.systemFont(ofSize: 30)
        timeStamp.alpha = 0.75
        timeStamp.text = now
        timeStamp.drawHierarchy(in: labelRect, afterScreenUpdates: true)

        
        //get the final image
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension ViewController {

//    func startListeningVolumeButton(_ volume: Float) {
//
//
//        let audioSession = AVAudioSession.sharedInstance()
//
//        do {
//            try audioSession.setActive(true)
//
//            let vol = audioSession.outputVolume
//            initialVolume = Float(vol.description)!
//            if initialVolume > 0.6 {
//                initialVolume -= 0.5
//            } else if initialVolume < 0.4 {
//                initialVolume += 0.5
//            }
//
//            audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
//        } catch {
//            print("Could not observe outputVolume ", error)
//        }
//    }
    
//    func setVolume(_ volume: Float) {
//
//        let audioSession = AVAudioSession.sharedInstance()
//
//        do {
//            try audioSession.setActive(true)
//
//        let volume = MPVolumeView(frame: .zero)
//        volume.setVolumeThumbImage(UIImage(), for: UIControl.State())
//        volume.isUserInteractionEnabled = false
//        volume.alpha = 0.00001
//        volume.showsRouteButton = false
//        view.addSubview(volume)
//
//        audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
//    } catch {
//    print("Could not observe outputVolume ", error)
//    }
//    }
    
        func setVolumeLevel(_ volumeLevel: Float) {
            let audioSession = AVAudioSession.sharedInstance()
            
            do {
                try audioSession.setActive(true)
                
                let volume = MPVolumeView(frame: .zero)
                volume.setVolumeThumbImage(UIImage(), for: UIControl.State())
                volume.isUserInteractionEnabled = false
                volume.alpha = 0.00001
                volume.showsRouteButton = false
                view.addSubview(volume)
                
                audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
                
                guard let slider = volume.subviews.compactMap({ $0 as? UISlider }).first else {
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
                    slider.value = volumeLevel
                }
                
                if slider.value >= 0.6 {
                    slider.value -= 0.19
                } else if slider.value <= 0.4 {
                    slider.value += 0.19
                }
                
            } catch {
                print("Could not observe outputVolume ", error)
            }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
           
            AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
            AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
            buttonPressed(Any?.self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}


