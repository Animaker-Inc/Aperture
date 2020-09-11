import Foundation
import AVFoundation

public final class Aperture: NSObject {
	public enum Error: Swift.Error {
		case invalidScreen
		case invalidAudioDevice
		case couldNotAddScreen
		case couldNotAddMic
		case couldNotAddOutput
	}

	var destination: URL
	private let session: AVCaptureSession
	private let output: AVCaptureMovieFileOutput
	    // private let output2: AVCaptureMovieFileOutput

	private var activity: NSObjectProtocol?

	public var onStart: (() -> Void)?
	public var onFinish: ((Swift.Error?) -> Void)?
		public var onFullFinish: ((Swift.Error?) -> Void)?

	public var onPause: (() -> Void)?
	public var onResume: (() -> Void)?
	public var isRecording: Bool { output.isRecording }
	public var isPaused: Bool { output.isRecordingPaused }
	//     public var isRecording2: Bool { output2.isRecording }
    // public var isPaused2: Bool { output2.isRecordingPaused }

    var timer = Timer()
    var timerCount = 0

	private init(
		destination: URL,
		input: AVCaptureInput,
		output: AVCaptureMovieFileOutput,
		audioDevice: AVCaptureDevice?,
		videoCodec: String?
	) throws {
		self.destination = destination
		session = AVCaptureSession()

		self.output = output
		        // self.output2 = AVCaptureMovieFileOutput()


		// Needed because otherwise there is no audio on videos longer than 10 seconds.
		// https://stackoverflow.com/a/26769529/64949
		output.movieFragmentInterval = .invalid
        // output2.movieFragmentInterval = .invalid

		if let audioDevice = audioDevice {
			if !audioDevice.hasMediaType(.audio) {
				throw Error.invalidAudioDevice
			}

			let audioInput = try AVCaptureDeviceInput(device: audioDevice)

			if session.canAddInput(audioInput) {
				session.addInput(audioInput)
			} else {
				throw Error.couldNotAddMic
			}
		}

		if session.canAddInput(input) {
			session.addInput(input)
		} else {
			throw Error.couldNotAddScreen
		}
        // if session.canAddOutput(output2) {
        //     session.addOutput(output2)
        // } else {
        //     throw Error.couldNotAddOutput
        // }
		if session.canAddOutput(output) {
			session.addOutput(output)
		} else {
			throw Error.couldNotAddOutput
		}
        



		// TODO: Default to HEVC when on 10.13 or newer and encoding is hardware supported. Without hardware encoding I got 3 FPS full screen recording.
		// TODO: Find a way to detect hardware encoding support.
		// Hardware encoding is supported on 6th gen Intel processor or newer.
		if let videoCodec = videoCodec {
						            // output2.setOutputSettings([AVVideoCodecKey: videoCodec], for: output2.connection(with: .video)!)

			output.setOutputSettings([AVVideoCodecKey: videoCodec], for: output.connection(with: .video)!)

		}

		super.init()
	}

	// TODO: When targeting macOS 10.13, make the `videoCodec` option the type `AVVideoCodecType`.
	/**
	Start a capture session with the given screen ID.

	Use `Aperture.Devices.screen()` to get a list of available screens.

	- Parameter destination: The destination URL where the captured video will be saved. Needs to be writable by current user.
	- Parameter framesPerSecond: The frames per second to be used for this capture.
	- Parameter cropRect: Optionally the screen capture can be cropped. Pass a `CGRect` to this initializer representing the crop area.
	- Parameter showCursor: Whether to show the cursor in the captured video.
	- Parameter highlightClicks: Whether to highlight clicks in the captured video.
	- Parameter screenId: The ID of the screen to be captured.
	- Parameter audioDevice: An optional audio device to capture.
	- Parameter videoCodec: The video codec to use when capturing.
	*/
	public convenience init(
		destination: URL,
		framesPerSecond: Int = 60,
		cropRect: CGRect? = nil,
		showCursor: Bool = true,
		highlightClicks: Bool = false,
		screenId: CGDirectDisplayID = .main,
		audioDevice: AVCaptureDevice? = .default(for: .audio),
		videoCodec: String? = nil
	) throws {
		let input = try AVCaptureScreenInput(displayID: screenId).unwrapOrThrow(Error.invalidScreen)

		input.minFrameDuration = CMTime(videoFramesPerSecond: framesPerSecond)

		if let cropRect = cropRect {
			input.cropRect = cropRect
		}

		input.capturesCursor = showCursor
		input.capturesMouseClicks = highlightClicks

		try self.init(
			destination: destination,
			input: input,
			output: AVCaptureMovieFileOutput(),
			audioDevice: audioDevice,
			videoCodec: videoCodec
		)
	}

	/**
	Start a capture session with the given iOS device.

	Use `Aperture.Devices.iOS()` to get a list of connected iOS devices and use the `.id` property to create an `AVCaptureDevice`:

	```
	AVCaptureDevice(uniqueID: id)
	```

	The frame rate is 60 frames per second.

	- Parameter destination: The destination URL where the captured video will be saved. Needs to be writable by current user.
	- Parameter iosDevice: The iOS device to capture.
	- Parameter audioDevice: An optional audio device to capture.
	- Parameter videoCodec: The video codec to use when capturing.
	*/
	public convenience init(
		destination: URL,
		iosDevice: AVCaptureDevice,
		audioDevice: AVCaptureDevice? = nil,
		videoCodec: String? = nil
	) throws {
		let input = try AVCaptureDeviceInput(device: iosDevice)

		try self.init(
			destination: destination,
			input: input,
			output: AVCaptureMovieFileOutput(),
			audioDevice: audioDevice,
			videoCodec: videoCodec
		)
	}

	public func start() {
		session.startRunning()
		output.startRecording(to: destination, recordingDelegate: self)
		timer = Timer.scheduledTimer(timeInterval: TimeInterval(10), target: self, selector: (#selector(updateRecording)), userInfo: nil, repeats: true)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
        //     self.updateRecording()
        // })
	}
    @objc func updateRecording(){
        timerCount += 1

        DispatchQueue.main.async(execute: {
            self.output.stopRecording()

        })

        DispatchQueue.main.async(execute: {

            self.output.startRecording(to: self.tempFile(), recordingDelegate: self)

        })


        // if isRecording{
		// 	DispatchQueue.main.async(execute: {
        //     self.output2.startRecording(to: self.tempFile(), recordingDelegate: self)

		// 	})
		// 	DispatchQueue.main.async(execute: {
        //     self.output.stopRecording()

		// 	})
        //     // timerCount += 1
        // }
        // else if isRecording2{
		// DispatchQueue.main.async(execute: {
        //     self.output.startRecording(to: self.tempFile(), recordingDelegate: self)

		// })
		// DispatchQueue.main.async(execute: {
        //     self.output2.stopRecording()

		// })

            // timerCount += 1
        // }

    }
    func tempFile() -> URL{
        var urlStr = destination.path
        urlStr = urlStr.dropLast(4) + "\(timerCount).mp4"
        return URL(fileURLWithPath: urlStr)
    }

	public func stop() {
        if isRecording{


            output.stopRecording()
        }
        // else if isRecording2{
        //     output2.stopRecording()
        // }

		// This prevents a race condition in Apple's APIs with the above and below calls.
		sleep(for: 0.1)

		self.session.stopRunning()

		onFullFinish?(nil)


	}

	public func pause() {
		output.pauseRecording()
	}

	public func resume() {
		output.resumeRecording()
	}
}

extension Aperture: AVCaptureFileOutputRecordingDelegate {
	private var shouldPreventSleep: Bool {
		get { activity != nil }
		set {
			if newValue {
				activity = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: "Recording screen")
			} else if let activity = activity {
				ProcessInfo.processInfo.endActivity(activity)
				self.activity = nil
			}
		}
	}

	public func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		shouldPreventSleep = true
		onStart?()
	}

	public func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Swift.Error?) {
		shouldPreventSleep = false
		onFinish?(error)
	}

	public func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		shouldPreventSleep = false
		onPause?()
	}

	public func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		shouldPreventSleep = true
		onResume?()
	}

	public func fileOutputShouldProvideSampleAccurateRecordingStart(_ output: AVCaptureFileOutput) -> Bool { true }
}
