import AVFoundation
import ImageIO
import UIKit

final class CameraSessionService: NSObject {
    enum FrameIssue: Equatable {
        case noFrameReceived
        case captureSessionNotRunning
        case invalidPixelBuffer(width: Int, height: Int, pixelFormat: OSType)

        var diagnosticLabel: String {
            switch self {
            case .noFrameReceived: return "no frame received"
            case .captureSessionNotRunning: return "capture session not running"
            case .invalidPixelBuffer: return "invalid pixel buffer"
            }
        }
    }

    struct FrameDiagnostics: Equatable {
        let deliveredFrameCount: Int
        let droppedFrameCount: Int
        let invalidFrameCount: Int
        let lastFrameAt: Date?
        let lastFrameWidth: Int?
        let lastFrameHeight: Int?
        let lastPixelFormat: OSType?
        let lastOrientation: CGImagePropertyOrientation?
        let lastIssue: FrameIssue?
    }

    enum CameraPosition: String, CaseIterable {
        case rear
        case front

        var capturePosition: AVCaptureDevice.Position {
            self == .rear ? .back : .front
        }
    }

    enum State: Equatable {
        case idle
        case requestingPermission
        case configuring
        case running
        case interrupted(String)
        case stopped
        case unavailable(String)
    }

    enum ServiceError: LocalizedError {
        case permissionDenied
        case cameraUnavailable
        case inputUnavailable
        case outputUnavailable
        case notRunning
        case photoDataUnavailable
        case torchUnavailable
        case configurationFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera access is off. Enable it in Settings to use Jarvis Vision."
            case .cameraUnavailable:
                return "A camera is not available right now."
            case .inputUnavailable:
                return "Jarvis could not connect to the camera."
            case .outputUnavailable:
                return "Jarvis could not prepare camera output."
            case .notRunning:
                return "The camera is not running."
            case .photoDataUnavailable:
                return "The captured image could not be read."
            case .torchUnavailable:
                return "The flashlight is unavailable on this camera."
            case .configurationFailed(let detail):
                return "Camera setup failed. \(detail)"
            }
        }
    }

    struct CapturedPhoto {
        let data: Data
        let image: UIImage
        let orientation: CGImagePropertyOrientation
    }

    let session = AVCaptureSession()

    var onFrame: ((CVPixelBuffer, CMTime, CGImagePropertyOrientation) -> Void)?
    var onStateChange: ((State) -> Void)?
    var onDroppedFrame: (() -> Void)?
    var onFrameIssue: ((FrameIssue) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.amrik.jarvisxr.camera.session", qos: .userInitiated)
    private let videoQueue = DispatchQueue(label: "com.amrik.jarvisxr.camera.video", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let orientationLock = NSLock()
    private let frameDiagnosticsLock = NSLock()
    private var activeDevice: AVCaptureDevice?
    private var configuredPosition: CameraPosition?
    private var cachedOrientation: CGImagePropertyOrientation = .right
    private var currentState: State = .idle
    private var shouldResumeAfterInterruption = false
    private var photoCompletion: ((Result<CapturedPhoto, Error>) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var deliveredFrameCount = 0
    private var droppedFrameCount = 0
    private var invalidFrameCount = 0
    private var lastFrameAt: Date?
    private var lastFrameWidth: Int?
    private var lastFrameHeight: Int?
    private var lastPixelFormat: OSType?
    private var lastFrameOrientation: CGImagePropertyOrientation?
    private var lastFrameIssue: FrameIssue?

    override init() {
        super.init()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        installObservers()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        shutdown()
    }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    var state: State {
        withSessionQueue { currentState }
    }

    var activePosition: CameraPosition? {
        withSessionQueue { configuredPosition }
    }

    var isTorchAvailable: Bool {
        withSessionQueue { activeDevice?.hasTorch == true }
    }

    var isTorchEnabled: Bool {
        withSessionQueue { activeDevice?.torchMode == .on }
    }

    var frameDiagnostics: FrameDiagnostics {
        frameDiagnosticsLock.lock()
        defer { frameDiagnosticsLock.unlock() }
        return FrameDiagnostics(
            deliveredFrameCount: deliveredFrameCount,
            droppedFrameCount: droppedFrameCount,
            invalidFrameCount: invalidFrameCount,
            lastFrameAt: lastFrameAt,
            lastFrameWidth: lastFrameWidth,
            lastFrameHeight: lastFrameHeight,
            lastPixelFormat: lastPixelFormat,
            lastOrientation: lastFrameOrientation,
            lastIssue: lastFrameIssue
        )
    }

    func requestAccessAndStart(
        position: CameraPosition = .rear,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        switch Self.authorizationStatus {
        case .authorized:
            start(position: position, completion: completion)
        case .notDetermined:
            transition(to: .requestingPermission)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.start(position: position, completion: completion)
                } else {
                    self.transition(to: .unavailable(ServiceError.permissionDenied.localizedDescription))
                    DispatchQueue.main.async { completion(.failure(ServiceError.permissionDenied)) }
                }
            }
        default:
            transition(to: .unavailable(ServiceError.permissionDenied.localizedDescription))
            DispatchQueue.main.async { completion(.failure(ServiceError.permissionDenied)) }
        }
    }

    func start(
        position: CameraPosition = .rear,
        completion: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard Self.authorizationStatus == .authorized else {
                self.transition(to: .unavailable(ServiceError.permissionDenied.localizedDescription))
                DispatchQueue.main.async { completion(.failure(ServiceError.permissionDenied)) }
                return
            }
            do {
                if self.configuredPosition != position || self.session.inputs.isEmpty {
                    try self.configure(position: position)
                }
                guard !self.session.isRunning else {
                    self.transition(to: .running)
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
                self.session.startRunning()
                self.shouldResumeAfterInterruption = true
                self.transition(to: .running)
                self.scheduleFirstFrameWatchdog(startingAt: self.frameDiagnostics.deliveredFrameCount)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                self.transition(to: .unavailable(error.localizedDescription))
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopSessionOnQueue()
            self.transition(to: .stopped)
        }
    }

    /// Completes capture cleanup before the owner is released. Unlike `stop()`, this
    /// method is synchronous and intentionally emits no callback during teardown.
    func shutdown() {
        withSessionQueue {
            stopSessionOnQueue()
            currentState = .stopped
        }
    }

    func switchCamera(completion: @escaping (Result<CameraPosition, Error>) -> Void) {
        let next: CameraPosition = activePosition == .front ? .rear : .front
        start(position: next) { result in
            completion(result.map { next })
        }
    }

    func captureHighResolutionPhoto(completion: @escaping (Result<CapturedPhoto, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                DispatchQueue.main.async { completion(.failure(ServiceError.notRunning)) }
                return
            }
            guard self.photoCompletion == nil else {
                DispatchQueue.main.async {
                    completion(.failure(ServiceError.configurationFailed("Another capture is still finishing.")))
                }
                return
            }
            self.photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = self.photoOutput.maxPhotoQualityPrioritization == .quality ? .quality : .balanced
            settings.flashMode = .off
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func setTorch(enabled: Bool, completion: @escaping (Result<Bool, Error>) -> Void = { _ in }) {
        sessionQueue.async { [weak self] in
            guard let self, let camera = self.activeDevice, camera.hasTorch else {
                DispatchQueue.main.async { completion(.failure(ServiceError.torchUnavailable)) }
                return
            }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                if enabled {
                    try camera.setTorchModeOn(level: min(AVCaptureDevice.maxAvailableTorchLevel, 0.55))
                } else {
                    camera.torchMode = .off
                }
                DispatchQueue.main.async { completion(.success(camera.torchMode == .on)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func configure(position: CameraPosition) throws {
        transition(to: .configuring)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720

        session.inputs.forEach(session.removeInput)
        if session.outputs.contains(videoOutput) {
            session.removeOutput(videoOutput)
        }
        if session.outputs.contains(photoOutput) {
            session.removeOutput(photoOutput)
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.capturePosition) else {
            throw ServiceError.cameraUnavailable
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            throw ServiceError.inputUnavailable
        }
        guard session.canAddInput(input) else { throw ServiceError.inputUnavailable }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        guard session.canAddOutput(videoOutput), session.canAddOutput(photoOutput) else {
            throw ServiceError.outputUnavailable
        }
        session.addOutput(videoOutput)
        session.addOutput(photoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            connection.isVideoMirrored = position == .front && connection.isVideoMirroringSupported
        }
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            connection.isVideoMirrored = position == .front && connection.isVideoMirroringSupported
        }

        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            camera.unlockForConfiguration()
        } catch {
            throw ServiceError.configurationFailed("Focus and exposure could not be prepared.")
        }

        activeDevice = camera
        configuredPosition = position
        setCachedOrientation(orientation(for: position))
        resetFrameDiagnostics()
    }

    private func scheduleFirstFrameWatchdog(startingAt baseline: Int) {
        sessionQueue.asyncAfter(deadline: .now() + 1.75) { [weak self] in
            guard let self, self.session.isRunning, self.currentState == .running else { return }
            guard self.frameDiagnostics.deliveredFrameCount == baseline else { return }
            self.record(issue: .noFrameReceived)
        }
    }

    private func resetFrameDiagnostics() {
        frameDiagnosticsLock.lock()
        deliveredFrameCount = 0
        droppedFrameCount = 0
        invalidFrameCount = 0
        lastFrameAt = nil
        lastFrameWidth = nil
        lastFrameHeight = nil
        lastPixelFormat = nil
        lastFrameOrientation = nil
        lastFrameIssue = nil
        frameDiagnosticsLock.unlock()
    }

    private func recordDeliveredFrame(
        width: Int,
        height: Int,
        pixelFormat: OSType,
        orientation: CGImagePropertyOrientation
    ) {
        frameDiagnosticsLock.lock()
        deliveredFrameCount += 1
        lastFrameAt = Date()
        lastFrameWidth = width
        lastFrameHeight = height
        lastPixelFormat = pixelFormat
        lastFrameOrientation = orientation
        lastFrameIssue = nil
        frameDiagnosticsLock.unlock()
    }

    private func recordDroppedFrame() {
        frameDiagnosticsLock.lock()
        droppedFrameCount += 1
        frameDiagnosticsLock.unlock()
        onDroppedFrame?()
    }

    private func record(issue: FrameIssue) {
        frameDiagnosticsLock.lock()
        if case .invalidPixelBuffer = issue { invalidFrameCount += 1 }
        lastFrameIssue = issue
        frameDiagnosticsLock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onFrameIssue?(issue) }
    }

    private func orientation(for position: CameraPosition?) -> CGImagePropertyOrientation {
        position == .front ? .leftMirrored : .right
    }

    private func setCachedOrientation(_ orientation: CGImagePropertyOrientation) {
        orientationLock.lock()
        cachedOrientation = orientation
        orientationLock.unlock()
    }

    private func currentOrientation() -> CGImagePropertyOrientation {
        orientationLock.lock()
        defer { orientationLock.unlock() }
        return cachedOrientation
    }

    @discardableResult
    private func withSessionQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: sessionQueueKey) == sessionQueueValue {
            return work()
        }
        return sessionQueue.sync(execute: work)
    }

    private func stopSessionOnQueue() {
        shouldResumeAfterInterruption = false
        disableTorchIfNeeded()
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func transition(to state: State) {
        if DispatchQueue.getSpecific(key: sessionQueueKey) == sessionQueueValue {
            currentState = state
            DispatchQueue.main.async { [weak self] in
                self?.onStateChange?(state)
            }
        } else {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.currentState = state
                DispatchQueue.main.async { [weak self] in
                    self?.onStateChange?(state)
                }
            }
        }
    }

    private let sessionQueueKey = DispatchSpecificKey<UInt8>()
    private let sessionQueueValue: UInt8 = 1

    private func installObservers() {
        sessionQueue.setSpecific(key: sessionQueueKey, value: sessionQueueValue)
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { [weak self] note in
            let reasonValue = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber
            let reason = reasonValue
                .flatMap { AVCaptureSession.InterruptionReason(rawValue: $0.intValue) }
                .map(Self.interruptionDescription) ?? "Camera interrupted."
            self?.transition(to: .interrupted(reason))
        })
        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            guard let self, self.shouldResumeAfterInterruption else { return }
            self.start(position: self.activePosition ?? .rear)
        })
        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { [weak self] note in
            let message = (note.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription
                ?? "Camera stopped unexpectedly."
            self?.transition(to: .unavailable(message))
        })
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.suspendForBackground()
        })
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.resumeFromBackgroundIfNeeded()
        })
    }

    private func suspendForBackground() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let wasRunning = self.session.isRunning && self.shouldResumeAfterInterruption
            self.disableTorchIfNeeded()
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.shouldResumeAfterInterruption = wasRunning
            if wasRunning {
                self.transition(to: .interrupted("Vision paused while Jarvis is in the background."))
            }
        }
    }

    private func resumeFromBackgroundIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, self.shouldResumeAfterInterruption, !self.session.isRunning else { return }
            self.session.startRunning()
            self.transition(to: .running)
        }
    }

    private func disableTorchIfNeeded() {
        guard let camera = activeDevice, camera.hasTorch, camera.torchMode == .on else { return }
        do {
            try camera.lockForConfiguration()
            camera.torchMode = .off
            camera.unlockForConfiguration()
        } catch {
            // Session shutdown must continue even if the torch cannot be changed.
        }
    }

    private static func interruptionDescription(_ reason: AVCaptureSession.InterruptionReason) -> String {
        switch reason {
        case .videoDeviceInUseByAnotherClient:
            return "The camera is being used by another app."
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            return "The camera is unavailable while multiple apps are active."
        case .videoDeviceNotAvailableDueToSystemPressure:
            return "The camera paused because the device is under pressure."
        case .audioDeviceInUseByAnotherClient:
            return "Audio was interrupted by another app."
        case .videoDeviceNotAvailableInBackground:
            return "Vision paused because the app is in the background."
        case .sensitiveContentMitigationActivated:
            return "The camera paused because sensitive content mitigation is active."
        @unknown default:
            return "Camera interrupted."
        }
    }
}

extension CameraSessionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard session.isRunning else {
            record(issue: .captureSessionNotRunning)
            recordDroppedFrame()
            return
        }
        guard CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            record(issue: .invalidPixelBuffer(width: 0, height: 0, pixelFormat: 0))
            recordDroppedFrame()
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard width > 1, height > 1 else {
            record(issue: .invalidPixelBuffer(width: width, height: height, pixelFormat: pixelFormat))
            recordDroppedFrame()
            return
        }
        let orientation = currentOrientation()
        recordDeliveredFrame(width: width, height: height, pixelFormat: pixelFormat, orientation: orientation)
        onFrame?(pixelBuffer, CMSampleBufferGetPresentationTimeStamp(sampleBuffer), orientation)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        recordDroppedFrame()
    }
}

extension CameraSessionService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let completion = withSessionQueue { () -> ((Result<CapturedPhoto, Error>) -> Void)? in
            defer { photoCompletion = nil }
            return photoCompletion
        }
        guard let completion else { return }
        if let error {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { completion(.failure(ServiceError.photoDataUnavailable)) }
            return
        }
        let captured = CapturedPhoto(data: data, image: image, orientation: currentOrientation())
        DispatchQueue.main.async { completion(.success(captured)) }
    }
}
