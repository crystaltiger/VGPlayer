//
//  VGPlayerView.swift
//  VGPlayer
//
//  Created by Vein on 2017/6/5.
//  Copyright © 2017年 Vein. All rights reserved.
//

import UIKit
import MediaPlayer
import SnapKit

public protocol VGPlayerViewDelegate: class {
    
    /// fullscreen
    func vgPlayerView(_ playerView: VGPlayerView, willFullscreen fullscreen: Bool)
    /// close play view
    func vgPlayerView(didTappedClose playerView: VGPlayerView)
    /// displaye control
    func vgPlayerView(didDisplayControl playerView: VGPlayerView)
}

// MARK: - delegate methods optional
public extension VGPlayerViewDelegate {
    
    func vgPlayerView(_ playerView: VGPlayerView, willFullscreen fullscreen: Bool){}
    
    func vgPlayerView(didTappedClose playerView: VGPlayerView) {}
    
    func vgPlayerView(didDisplayControl playerView: VGPlayerView) {}
}


public enum VGPlayerViewPanGestureDirection: Int {
    case vertical
    case horizontal
}

open class VGPlayerView: UIView {
    
    open weak var vgPlayer : VGPlayer?
    open fileprivate(set) var playerLayer : AVPlayerLayer?
    open fileprivate(set) var fullScreen : Bool = false
    open fileprivate(set) var timeSliding : Bool = false
    open fileprivate(set) var isDisplayControl : Bool = true {
        didSet {
            if isDisplayControl != oldValue {
                delegate?.vgPlayerView(didDisplayControl: self)
            }
        }
    }
    open weak var delegate : VGPlayerViewDelegate?
    // top view
    open var topView : UIView = {
        let view = UIView()
        view.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        return view
    }()
    open var titleLabel : UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = UIFont.boldSystemFont(ofSize: 16.0)
        return label
    }()
    open var closeButton : UIButton = {
        let button = UIButton(type: UIButtonType.custom)
        return button
    }()
    
    // bottom view
    open var bottomView : UIView = {
        let view = UIView()
        view.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        return view
    }()
    open var timeSlider = VGPlayerSlider ()
    open var loadingIndicator = VGPlayerLoadingIndicator()
    open var fullscreenButton : UIButton = UIButton(type: UIButtonType.custom)
    open var timeLabel : UILabel = UILabel()
    open var playButtion : UIButton = UIButton(type: UIButtonType.custom)
    open var volumeSlider : UISlider!
    open var replayButton : UIButton = UIButton(type: UIButtonType.custom)
    open fileprivate(set) var panGestureDirection : VGPlayerViewPanGestureDirection = .horizontal
    fileprivate var isVolume : Bool = false
    fileprivate var sliderSeekTimeValue : TimeInterval = .nan
    fileprivate var timer : Timer = {
        let time = Timer()
        return time
    }()
    
    fileprivate weak var parentView : UIView?
    fileprivate var viewFrame = CGRect()
    
    // GestureRecognizer
    open var singleTapGesture = UITapGestureRecognizer()
    open var doubleTapGesture = UITapGestureRecognizer()
    open var panGesture = UIPanGestureRecognizer()
    
    //MARK:- life cycle
    public override init(frame: CGRect) {
        self.playerLayer = AVPlayerLayer(player: nil)
        super.init(frame: frame)
        addDeviceOrientationNotifications()
        addGestureRecognizer()
        configurationVolumeSlider()
        configurationUI()
    }
    
    public convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer.invalidate()
        playerLayer?.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        updateDisplayerView(frame: bounds)
    }
    
    open func setvgPlayer(vgPlayer: VGPlayer) {
        self.vgPlayer = vgPlayer
    }
    
    open func reloadPlayerLayer() {
        self.playerLayer = AVPlayerLayer(player: self.vgPlayer?.player)
        self.layer.insertSublayer(self.playerLayer!, at: 0)
        self.updateDisplayerView(frame: self.bounds)
        self.timeSlider.isUserInteractionEnabled = self.vgPlayer?.mediaFormat != .m3u8
        reloadGravity()
    }
    
    
    /// play state did change
    ///
    /// - Parameter state: state
    open func playStateDidChange(_ state: VGPlayerState) {
        self.playButtion.isSelected = state == .playing
        self.replayButton.isHidden = !(state == .playFinished)
        self.replayButton.isHidden = !(state == .playFinished)
        if state == .playing || state == .playFinished {
            setupTimer()
        }
    }
    
    /// buffer state change
    ///
    /// - Parameter state: buffer state
    open func bufferStateDidChange(_ state: VGPlayerBufferstate) {
        if state == .buffering {
            self.loadingIndicator.isHidden = false
            self.loadingIndicator.startAnimating()
        } else {
            self.loadingIndicator.isHidden = true
            self.loadingIndicator.stopAnimating()
        }
        
        var current = formatSecondsToString((self.vgPlayer?.currentDuration)!)
        if (self.vgPlayer?.totalDuration.isNaN)! {  // HLS
            current = "00:00"
        }
        if state == .readyToPlay && !timeSliding {
            self.timeLabel.text = "\(current + " / " +  (formatSecondsToString((self.vgPlayer?.totalDuration)!)))"
        }
    }
    
    /// buffer duration
    ///
    /// - Parameters:
    ///   - bufferedDuration: buffer duration
    ///   - totalDuration: total duratiom
    open func bufferedDidChange(_ bufferedDuration: TimeInterval, totalDuration: TimeInterval) {
        self.timeSlider.setProgress(Float(bufferedDuration / totalDuration), animated: true)
    }
    
    /// player diration
    ///
    /// - Parameters:
    ///   - currentDuration: current duration
    ///   - totalDuration: total duration
    open func playerDurationDidChange(_ currentDuration: TimeInterval, totalDuration: TimeInterval) {
        var current = formatSecondsToString(currentDuration)
        if totalDuration.isNaN {  // HLS
            current = "00:00"
        }
        if !timeSliding {
            self.timeLabel.text = "\(current + " / " +  (formatSecondsToString(totalDuration)))"
            self.timeSlider.value = Float(currentDuration / totalDuration)
        }
    }
    
}

// MARK: - public
extension VGPlayerView {
    
    open func updateDisplayerView(frame: CGRect) {
        self.playerLayer?.frame = frame
    }
    
    open func reloadPlayerView() {
        self.playerLayer = AVPlayerLayer(player: nil)
        self.timeSlider.value = Float(0)
        self.timeSlider.setProgress(0, animated: false)
        self.replayButton.isHidden = true
        self.timeSliding = false
        self.loadingIndicator.isHidden = false
        self.loadingIndicator.startAnimating()
        self.timeLabel.text = "--:-- / --:--"
        reloadPlayerLayer()
    }
    
    open func reloadGravity() {
        if self.vgPlayer != nil {
            switch self.vgPlayer!.gravityMode {
            case .resize:
                self.playerLayer?.videoGravity = "AVLayerVideoGravityResize"
            case .resizeAspect:
                self.playerLayer?.videoGravity = "AVLayerVideoGravityResizeAspect"
            case .resizeAspectFill:
                self.playerLayer?.videoGravity = "AVLayerVideoGravityResizeAspectFill"
            }
        }
    }
    
    /// control view display
    ///
    /// - Parameter display: is display
    open func displayControlView(_ isDisplay:Bool) {
        if isDisplay {
            displayControlAnimation()
        } else {
            hiddenControlAnimation()
        }
    }
    open func enterFullscreen() {
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation == .portrait{
            self.parentView = (self.superview)!
            self.viewFrame = self.frame
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIApplication.shared.statusBarOrientation = .landscapeRight
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
    }
    
    open func exitFullscreen() {
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIApplication.shared.statusBarOrientation = .portrait
    }
    
    /// play failed
    ///
    /// - Parameter error: error
    open func playFailed(_ error: VGPlayerError) {
        // error
    }
    
    public func formatSecondsToString(_ secounds: TimeInterval) -> String {
        if secounds.isNaN{
            return "00:00"
        }
        let interval = Int(secounds)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - private
extension VGPlayerView {
    
    internal func play() {
        self.playButtion.isSelected = true
    }
    
    internal func pause() {
        self.playButtion.isSelected = false
    }
    
    internal func displayControlAnimation() {
        self.bottomView.isHidden = false
        self.topView.isHidden = false
        self.isDisplayControl = true
        UIView.animate(withDuration: 0.5, animations: {
            self.bottomView.alpha = 1
            self.topView.alpha = 1
        }) { (completion) in
            self.setupTimer()
        }
    }
    internal func hiddenControlAnimation() {
        self.timer.invalidate()
        self.isDisplayControl = false
        UIView.animate(withDuration: 0.5, animations: {
            self.bottomView.alpha = 0
            self.topView.alpha = 0
        }) { (completion) in
            self.bottomView.isHidden = true
            self.topView.isHidden = true
        }
    }
    internal func setupTimer() {
        self.timer.invalidate()
        self.timer = Timer.vgPlayer_scheduledTimerWithTimeInterval(3, block: {  [weak self]  in
            guard let strongSelf = self else { return }
            strongSelf.displayControlView(false)
        }, repeats: false)
    }
    internal func addDeviceOrientationNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationWillChange(_:)), name: .UIApplicationWillChangeStatusBarOrientation, object: nil)
    }
    
    internal func configurationVolumeSlider() {
        var slider = UISlider()
        let volumeView = MPVolumeView()
        if let view = volumeView.subviews.first as? UISlider {
            self.volumeSlider = view
        }
    }
}


// MARK: - GestureRecognizer
extension VGPlayerView {
    
    internal func addGestureRecognizer() {
        self.singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onSingleTapGesture(_:)))
        self.singleTapGesture.numberOfTapsRequired = 1
        self.singleTapGesture.numberOfTouchesRequired = 1
        self.singleTapGesture.delegate = self
        addGestureRecognizer(self.singleTapGesture)
        
        self.doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onDoubleTapGesture(_:)))
        self.doubleTapGesture.numberOfTapsRequired = 2
        self.doubleTapGesture.numberOfTouchesRequired = 1
        self.doubleTapGesture.delegate = self
        addGestureRecognizer(self.doubleTapGesture)
        
        self.panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPanGesture(_:)))
        self.panGesture.delegate = self
        addGestureRecognizer(self.panGesture)
        
        self.singleTapGesture.require(toFail: doubleTapGesture)
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension VGPlayerView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view as? VGPlayerView != nil) {
            return true
        }
        return false
    }
}

// MARK: - Event
extension VGPlayerView {
    
    internal func timeSliderValueChanged(_ sender: VGPlayerSlider) {
        self.timeSliding = true
        if let duration = self.vgPlayer?.totalDuration {
            let currentTime = Double(sender.value) * duration
            self.timeLabel.text = "\(formatSecondsToString(currentTime) + " / " +  (formatSecondsToString(duration)))"
        }
    }
    
    internal func timeSliderTouchDown(_ sender: VGPlayerSlider) {
        self.timeSliding = true
        self.timer.invalidate()
    }
    
    internal func timeSliderTouchUpInside(_ sender: VGPlayerSlider) {
        self.timeSliding = true
        
        if let duration = self.vgPlayer?.totalDuration {
            let currentTime = Double(sender.value) * duration
            self.vgPlayer?.seekTime(currentTime, completion: { [weak self] (finished) in
                guard let strongSelf = self else { return }
                if finished {
                    strongSelf.timeSliding = false
                    strongSelf.setupTimer()
                }
            })
            self.timeLabel.text = "\(formatSecondsToString(currentTime) + " / " +  (formatSecondsToString(duration)))"
        }
    }
    
    internal func onPlayerButton(_ sender: UIButton) {
        if !sender.isSelected {
            self.vgPlayer?.play()
        } else {
            self.vgPlayer?.pause()
        }
    }
    
    internal func onFullscreen(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        self.fullScreen = sender.isSelected
        if fullScreen {
            enterFullscreen()
        } else {
            exitFullscreen()
        }
        delegate?.vgPlayerView(self, willFullscreen: self.fullScreen)
    }
    
    internal func onSingleTapGesture(_ gesture: UITapGestureRecognizer) {
        self.isDisplayControl = !self.isDisplayControl
        displayControlView(self.isDisplayControl)
    }
    
    internal func onDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        
        guard self.vgPlayer == nil else {
            switch self.vgPlayer!.state {
            case .playFinished:
                break
            case .playing:
                self.vgPlayer?.pause()
            case .paused:
                self.vgPlayer?.play()
            case .none:
                break
            case .error:
                break
            }
            return
        }
    }
    
    internal func onPanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let location = gesture.location(in: self)
        let velocity = gesture.velocity(in: self)
        switch gesture.state {
        case .began:
            let x = fabs(translation.x)
            let y = fabs(translation.y)
            if x < y {
                self.panGestureDirection = .vertical
                if location.x > self.bounds.width / 2{
                    self.isVolume = true
                } else {
                    self.isVolume = false
                }
            } else if x > y{
                guard vgPlayer?.mediaFormat == .m3u8 else {
                    self.panGestureDirection = .horizontal
                    return
                }
            }
        case .changed:
            switch self.panGestureDirection {
            case .horizontal:
                if self.vgPlayer?.currentDuration == 0 { break }
                self.sliderSeekTimeValue = panGestureHorizontal(velocity.x)
            case .vertical:
                panGestureVertical(velocity.y)
            }
        case .ended:
            switch self.panGestureDirection{
            case .horizontal:
                if sliderSeekTimeValue.isNaN { return }
                self.vgPlayer?.seekTime(self.sliderSeekTimeValue, completion: { [weak self] (finished) in
                    guard let strongSelf = self else { return }
                    if finished {
                        
                        strongSelf.timeSliding = false
                        strongSelf.setupTimer()
                    }
                })
            case .vertical:
                self.isVolume = false
            }
            
        default:
            break
        }
    }
    
    internal func panGestureHorizontal(_ velocityX: CGFloat) -> TimeInterval {
        self.displayControlView(true)
        self.timeSliding = true
        self.timer.invalidate()
        let value = self.timeSlider.value
        if let currentDuration = self.vgPlayer?.currentDuration ,let totalDuration = self.vgPlayer?.totalDuration{
            let sliderValue = (TimeInterval(value) *  totalDuration) + TimeInterval(velocityX) / 100.0 * (TimeInterval(totalDuration) / 400)
            self.timeSlider.setValue(Float(sliderValue/totalDuration), animated: true)
            return sliderValue
        } else {
            return TimeInterval.nan
        }
        
    }
    
    internal func panGestureVertical(_ velocityY: CGFloat) {
        self.isVolume ? (self.volumeSlider.value -= Float(velocityY / 10000)) : (UIScreen.main.brightness -= velocityY / 10000)
    }

    internal func onCloseView(_ sender: UIButton) {
        delegate?.vgPlayerView(didTappedClose: self)
    }
    
    internal func onReplay(_ sender: UIButton) {
        self.vgPlayer?.replaceVideo((self.vgPlayer?.contentURL)!)
        self.vgPlayer?.play()
    }
    
    internal func deviceOrientationWillChange(_ sender: Notification) {
        let orientation = UIDevice.current.orientation
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation == .portrait{
            if self.superview != nil {
                self.parentView = (self.superview)!
                self.viewFrame = self.frame
            }
        }
        switch orientation {
        case .unknown:
            break
        case .faceDown:
            break
        case .faceUp:
            break
        case .landscapeLeft:
            onDeviceOrientation(true, orientation: .landscapeLeft)
        case .landscapeRight:
            onDeviceOrientation(true, orientation: .landscapeRight)
        case .portrait:
            onDeviceOrientation(false, orientation: .portrait)
        case .portraitUpsideDown:
            onDeviceOrientation(false, orientation: .portraitUpsideDown)
        }
    }
    internal func onDeviceOrientation(_ fullScreen: Bool, orientation: UIInterfaceOrientation) {
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if orientation == statusBarOrientation {
            if orientation == .landscapeLeft || orientation == .landscapeLeft {
                let rectInWindow = self.convert(self.bounds, to: UIApplication.shared.keyWindow)
                self.removeFromSuperview()
                self.frame = rectInWindow
                UIApplication.shared.keyWindow?.addSubview(self)
                self.snp.remakeConstraints({ [weak self] (make) in
                    guard let strongSelf = self else { return }
                    make.width.equalTo(strongSelf.superview!.bounds.width)
                    make.height.equalTo(strongSelf.superview!.bounds.height)
                })
            }
        } else {
            if orientation == .landscapeLeft || orientation == .landscapeRight {
                let rectInWindow = self.convert(self.bounds, to: UIApplication.shared.keyWindow)
                self.removeFromSuperview()
                self.frame = rectInWindow
                UIApplication.shared.keyWindow?.addSubview(self)
                self.snp.remakeConstraints({ [weak self] (make) in
                    guard let strongSelf = self else { return }
                    make.width.equalTo(strongSelf.superview!.bounds.height)
                    make.height.equalTo(strongSelf.superview!.bounds.width)
                })
            } else if orientation == .portrait{
                if self.parentView == nil { return }
                self.removeFromSuperview()
                self.parentView!.addSubview(self)
                let frame = self.parentView!.convert(self.viewFrame, to: UIApplication.shared.keyWindow)
                self.snp.remakeConstraints({ (make) in
                    make.width.equalTo(frame.width)
                    make.height.equalTo(frame.height)
                })
                self.viewFrame = CGRect()
                self.parentView = nil
            }
        }
        self.fullScreen = fullScreen
        self.fullscreenButton.isSelected = fullScreen
        delegate?.vgPlayerView(self, willFullscreen: self.fullScreen)
    }
}

//MARK: - UI autoLayout
extension VGPlayerView {
    
    open func configurationUI() {
        self.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        configurationTopView()
        configurationBottomView()
        configurationReplayButton()
        setupViewAutoLayout()
    }
    
    internal func configurationReplayButton() {
        addSubview(self.replayButton)
        let replayImage = VGPlayerUtils.imageResource("VGPlayer_ic_replay")
        self.replayButton.setImage(VGPlayerUtils.imageSize(image: replayImage!, scaledToSize: CGSize(width: 30, height: 30)), for: .normal)
        self.replayButton.addTarget(self, action: #selector(onReplay(_:)), for: .touchUpInside)
        self.replayButton.isHidden = true
    }
    
    internal func configurationTopView() {
        addSubview(self.topView)
        self.titleLabel.text = "this is a title."
        self.topView.addSubview(self.titleLabel)
        let closeImage = VGPlayerUtils.imageResource("VGPlayer_ic_nav_back")
        self.closeButton.setImage(VGPlayerUtils.imageSize(image: closeImage!, scaledToSize: CGSize(width: 15, height: 20)), for: .normal)
        self.closeButton.addTarget(self, action: #selector(onCloseView(_:)), for: .touchUpInside)
        self.topView.addSubview(self.closeButton)
    }
    
    internal func configurationBottomView() {
        addSubview(self.bottomView)
        self.timeSlider.addTarget(self, action: #selector(timeSliderValueChanged(_:)),
                             for: .valueChanged)
        self.timeSlider.addTarget(self, action: #selector(timeSliderTouchUpInside(_:)), for: .touchUpInside)
        self.timeSlider.addTarget(self, action: #selector(timeSliderTouchDown(_:)), for: .touchDown)
        self.loadingIndicator.lineWidth = 1.0
        self.loadingIndicator.isHidden = false
        self.loadingIndicator.startAnimating()
        addSubview(self.loadingIndicator)
        self.bottomView.addSubview(self.timeSlider)
        
        let playImage = VGPlayerUtils.imageResource("VGPlayer_ic_play")
        let pauseImage = VGPlayerUtils.imageResource("VGPlayer_ic_pause")
        self.playButtion.setImage(VGPlayerUtils.imageSize(image: playImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .normal)
        self.playButtion.setImage(VGPlayerUtils.imageSize(image: pauseImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .selected)
        self.playButtion.addTarget(self, action: #selector(onPlayerButton(_:)), for: .touchUpInside)
        self.bottomView.addSubview(self.playButtion)
        
        self.timeLabel.textAlignment = .center
        self.timeLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        self.timeLabel.font = UIFont.systemFont(ofSize: 12.0)
        self.timeLabel.text = "--:-- / --:--"
        self.bottomView.addSubview(self.timeLabel)
        
        let enlargeImage = VGPlayerUtils.imageResource("VGPlayer_ic_fullscreen")
        let narrowImage = VGPlayerUtils.imageResource("VGPlayer_ic_fullscreen_exit")
        self.fullscreenButton.setImage(VGPlayerUtils.imageSize(image: enlargeImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .normal)
        self.fullscreenButton.setImage(VGPlayerUtils.imageSize(image: narrowImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .selected)
        self.fullscreenButton.addTarget(self, action: #selector(onFullscreen(_:)), for: .touchUpInside)
        self.bottomView.addSubview(self.fullscreenButton)
        
    }
    
    internal func setupViewAutoLayout() {
        replayButton.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.center.equalTo(strongSelf)
            make.width.equalTo(30)
            make.height.equalTo(30)
        }
        
        // top view layout
        topView.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf)
            make.right.equalTo(strongSelf)
            make.top.equalTo(strongSelf)
            make.height.equalTo(64)
        }
        closeButton.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf.topView).offset(10)
            make.top.equalTo(strongSelf.topView).offset(28)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
        titleLabel.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf.closeButton.snp.right).offset(20)
            make.centerY.equalTo(strongSelf.closeButton.snp.centerY)
        }
        
        // bottom view layout
        bottomView.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf)
            make.right.equalTo(strongSelf)
            make.bottom.equalTo(strongSelf)
            make.height.equalTo(52)
        }
        
        playButtion.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf.bottomView).offset(20)
            make.height.equalTo(25)
            make.width.equalTo(25)
            make.centerY.equalTo(strongSelf.bottomView)
        }
        
        timeLabel.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.right.equalTo(strongSelf.fullscreenButton.snp.left).offset(-10)
            make.centerY.equalTo(strongSelf.playButtion)
            make.height.equalTo(30)
        }
        
        timeSlider.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.centerY.equalTo(strongSelf.playButtion)
            make.right.equalTo(strongSelf.timeLabel.snp.left).offset(-10)
            make.left.equalTo(strongSelf.playButtion.snp.right).offset(25)
            make.height.equalTo(25)
        }
        fullscreenButton.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.centerY.equalTo(strongSelf.playButtion)
            make.right.equalTo(strongSelf.bottomView).offset(-10)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
        
        loadingIndicator.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.center.equalTo(strongSelf)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
    }
}
