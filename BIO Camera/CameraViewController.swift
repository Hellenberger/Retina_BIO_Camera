//  CameraViewController.swift
//  ReplicateCameraView
//
//  Created by Howard EllenbesetTorchModeOnrger on 6/19/19.
//  Copyright © 2019 Howard Ellenberger. All rights reserved.

import UIKit
import CoreAudio
import MediaPlayer
import AVFoundation
import Photos
import AudioToolbox





class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    lazy var torchTo = SettingsViewController().torchTo
    var finalTorchLevel = Float()
    var finalZoomLevel = CGFloat()
    lazy var zoomTo = SettingsViewController().zoomTo
    
    let shutterSound = Bundle.main.url(forResource: "shutter_click", withExtension: "mp3")
    
    let backCamera = AVCaptureDevice.videoDevice()

    var timestamp : Double!

    var audioPlayer : AVAudioPlayer!

    @IBOutlet weak var labelView : UIView!
    
    @IBOutlet weak var timeStamp : UILabel!
        var now = ""
 
    @IBOutlet weak var imageSaved : UILabel!
    
    @IBOutlet var mainView : UIView!
    
    @IBOutlet weak var cameraView: UIImageView!
    
    let viewBackgroundColor : UIColor = UIColor.black
    
    @IBOutlet weak var continuousFocusSlider: UISlider!
    @IBOutlet weak var focusLabel: UILabel!
    
    @IBOutlet weak var torchSlider: UISlider!
    @IBOutlet weak var torchLabel: UILabel!
    
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
    
    override var prefersStatusBarHidden: Bool { return true }

    @IBAction func tapFocusControl(_ sender: UITapGestureRecognizer) {
        self.continuousFocusSlider.fadeOut2(completion: {
            (finished: Bool) -> Void in
            self.continuousFocusSlider.fadeIn2()
            
            self.continuousFocusSlider.fadeOut2()
        })
    }
    
    @IBAction func tapLightLevelControl(_ sender: UITapGestureRecognizer) {
        self.torchSlider.fadeOut2(completion: {
            (finished: Bool) -> Void in
            self.torchSlider.fadeIn2()
            self.torchSlider.fadeOut2()
        })
    }
    
    @IBAction func continuousFocusSliderValueChanged(_ sender: UISlider) {
    let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()

        device?.setFocusModeLocked(lensPosition: sender.value)
        continuousFocusSlider.minimumValue = 0.0
        continuousFocusSlider.maximumValue = 1.0
        device?.unlockForConfiguration()
        } catch {
        }
    }

    @IBAction func torchLevelChanged(_ sender: UISlider) {
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
                if torchSlider.value > 0.1 {
                                  try? backCamera?.setTorchModeOn(level: torchSlider.value)
                   
                       } else {
                           torchSlider.value = 0.3
                       }
                   try device.setTorchModeOn(level: torchSlider.value)
                   torchTo = torchSlider.value
               } catch {
                   print(error)
               }
       } catch {
           print(error)
       }
       
       self.backCamera?.unlockForConfiguration()
    }
    
    @IBAction func buttonPressed(_ sender: Any?) {
        
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

extension CameraViewController {
    
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

extension CameraViewController {
    
    func startListeningVolume() {
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(true)
            audioSession.addObserver(self, forKeyPath: "outputVolume",
                                     options: NSKeyValueObservingOptions.new, context: nil)
                let volume = MPVolumeView(frame: .zero)
                volume.setVolumeThumbImage(UIImage(), for: UIControl.State())
                volume.isUserInteractionEnabled = false
                volume.alpha = 0.00001
                volume.showsRouteButton = false
                view.addSubview(volume)
                
              }
            
         catch {
            print("Could not observe outputVolume ", error)
        }
    }
    
    func setVolume(_volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = 0.25
        }
    }
    
    func initialVolumeLevel() {

        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            try device.lockForConfiguration()
            setVolume(_volume:  0.25)
            
        } catch {
            debugPrint(error)
        }
        device.unlockForConfiguration()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            buttonPressed(Any?.self)
            setVolume(_volume: 0.25)
            AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
            AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        }
    }

    func flashAndZoom() {

        guard backCamera!.hasTorch else { return }
             do {
                try backCamera?.lockForConfiguration()

                if (backCamera?.torchMode == AVCaptureDevice.TorchMode.off) {
                    backCamera?.torchMode = AVCaptureDevice.TorchMode.on
                    try backCamera?.setTorchModeOn(level: finalTorchLevel)
                }
                } catch {
                     print("error")
                }
            backCamera?.unlockForConfiguration()

            print("post segue finalTorchLevel = ", finalTorchLevel)
            print("post segue finalZoomLevel = ", finalZoomLevel)
         }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        torchSlider.alpha = 0.20
        continuousFocusSlider.alpha = 0.20
        initialVolume = 0.25

        let cameraView = CALayer()
        let replicatorLayer = CAReplicatorLayer()
        let instanceCount = 2
        replicatorLayer.instanceCount = 2
        replicatorLayer.instanceCount = instanceCount
        replicatorLayer.frame = CGRect(x: 0, y: 20, width: 300, height: 275)
        replicatorLayer.instanceTransform = CATransform3DMakeTranslation(345, 0, 0)
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
        } else {
            // Below iOS 10.0
            
            let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
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
                    do {
                       try backCamera.lockForConfiguration()
                        
                    guard backCamera.hasTorch else { return }
                    let torchOn = !backCamera.isTorchActive
                    try backCamera.setTorchModeOn(level: finalTorchLevel)
                    backCamera.torchMode = torchOn ? .on : .off
                }
                    if (backCamera.responds(to: #selector(setter: AVCaptureDevice.videoZoomFactor))) {
                        backCamera.videoZoomFactor = max(1.0, min(CGFloat(finalZoomLevel), (backCamera.activeFormat.videoMaxZoomFactor)))
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
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
        flashAndZoom()

        startListeningVolume()
        setVolume(_volume: 0.25)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
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
  
        let bracketedSettings: [AVCaptureBracketedStillImageSettings]
        if backCamera?.exposureMode == .custom {
            bracketedSettings = [AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: AVCaptureDevice.currentExposureDuration, iso: AVCaptureDevice.currentISO)]
        } else {
            bracketedSettings = [AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: AVCaptureDevice.currentExposureTargetBias)]
        }
        
        let  settings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg], bracketedSettings: bracketedSettings)
            //AVCapturePhotoSettings()

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
    
    func fadeIn2(_ duration: TimeInterval = 0.0, delay: TimeInterval = 0.01, completion: @escaping ((Bool) -> Void) = {(finished: Bool) -> Void in}) {
           UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
               self.alpha = 1.0
               }, completion: completion)  }

       func fadeOut2(_ duration: TimeInterval = 0.25, delay: TimeInterval = 0.5, completion: @escaping (Bool) -> Void = {(finished: Bool) -> Void in}) {
           UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
               self.alpha = 0.2
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

extension CameraViewController {
   
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

extension CameraViewController {
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
    do { try AVAudioSession.sharedInstance().setActive(false) }
    catch { debugPrint("\(error)") }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}


