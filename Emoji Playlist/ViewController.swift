//
//  ViewController.swift
//  Emoji Playlist
//
//  Created by DFA Film 9: K-9 on 4/14/15.
//  Copyright (c) 2015 Cal Stephens. All rights reserved.
//

import UIKit
import iAd

let EIShowHelpPopupNotification = "com.cal.emojicon.show-help-popup"
let EIShowKeyboardNotification = "com.cal.emojicon.show-keyboard"

class ViewController: UIViewController, ADBannerViewDelegate {
    
    @IBOutlet weak var hiddenField: UITextField!
    @IBOutlet weak var showKeyboardButton: UIButton!
    @IBOutlet weak var openKeyboardView: UIView!
    @IBOutlet weak var openKeyboardPosition: NSLayoutConstraint!
    @IBOutlet weak var contentHeight: NSLayoutConstraint!
    
    @IBOutlet weak var topBar: UIView!
    @IBOutlet weak var emojiView: UIView!
    @IBOutlet weak var emojiLabel: UILabel!
    @IBOutlet weak var emojiNameLabel: UILabel!
    @IBOutlet weak var previousEmojiImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateContentHeight(animate: false)
        changeToEmoji("😀", animate: false)
        emojiNameLabel.text = "Open the Emoji Keyboard and press an emoji"
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardChanged:", name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardChanged:", name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showHelpPopup:", name: EIShowHelpPopupNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showKeyboard", name: EIShowKeyboardNotification, object: nil)
        
        self.openKeyboardView.transform = CGAffineTransformMakeScale(0.01, 0.01)
        self.openKeyboardView.layer.cornerRadius = 20.0
        self.openKeyboardView.layer.masksToBounds = true
        
        showKeyboardButton.alpha = 0.0
        UIView.animateWithDuration(0.5, delay: 1.0, options: [], animations: {
            self.showKeyboardButton.alpha = 1.0
        }, completion: nil)
    }
    
    //MARK: - Showing and Hiding the Keyboard
    
    @IBAction func showKeyboard() { //called from app delegate or UIButton
        hiddenField.becomeFirstResponder()
        UIView.animateWithDuration(0.3, animations: {
            self.adBanner.alpha = 1.0
            self.showKeyboardButton.alpha = 1.0
        })
    }
    
    func hideAd() {
        self.adBanner.alpha = 0.0
        showKeyboardButton.alpha = 0.0
    }
    
    var keyboardHidden = false
    
    func keyboardChanged(notification: NSNotification) {
        let info = notification.userInfo!
        let value: AnyObject = info[UIKeyboardFrameEndUserInfoKey]!
        
        let rawFrame = value.CGRectValue
        let keyboardFrame = view.convertRect(rawFrame, fromView: nil)
        self.keyboardHeight = keyboardFrame.height
        
        let duration = "\(info[UIKeyboardAnimationDurationUserInfoKey]!)"
        updateContentHeight(animate: duration != "0")
        
        if !adBanner.bannerLoaded {
            //ad is not on screen
            keyboardHidden = false
            return
        }
        
        adPosition.constant = keyboardHeight
        
        if keyboardHidden {
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: { self.view.layoutIfNeeded() }, completion: nil)
        } else {
            self.view.layoutIfNeeded()
        }
        
        keyboardHidden = false
        
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

    var isAnimatingPopup = false
    
    func showOpenKeyboardPopup() {
        
        if isAnimatingPopup { return }
        isAnimatingPopup = true
        self.openKeyboardView.alpha = 1.0
        
        UIView.animateWithDuration(1.0, delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.0, options: [], animations: {
            self.openKeyboardView.transform = CGAffineTransformIdentity
        }, completion: nil)
        
        UIView.animateWithDuration(0.4, delay: 2.5, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.openKeyboardView.transform = CGAffineTransformMakeScale(0.0001, 0.0001)
        }, completion: { _ in
            self.isAnimatingPopup = false
            self.openKeyboardView.alpha = 0.0
        })
        
    }
    
    func updateContentHeight(animate animate: Bool = true) {
        let adBannerHidden = adPosition.constant == -adBanner.frame.height || !shouldShowAds || adBanner.hidden || adBanner.alpha == 0.0
        let availableHeight = self.view.frame.height - keyboardHeight - (adBannerHidden ? 0 : adBanner.frame.height)
        contentHeight.constant = availableHeight
        
        UIView.animateWithDuration(animate ? 0.4 : 0.0, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    //MARK: - emoji input and processing
    
    @IBAction func hiddenInputReceived(sender: UITextField, forEvent event: UIEvent) {
        let rawEmoji = sender.text!
        sender.text = nil
        
        if rawEmoji == "" { return }
        var emoji = rawEmoji as NSString
        
        let notEmoji = "abcdefghijklmnopqrstuvwxyz1234567890-=!@#$%^&*()_+,./;'[]\\<>?:\"{}| "
        for character in rawEmoji.characters {
            if notEmoji.containsString("\(character)".lowercaseString) {
                sender.text = ""
                //show an alert
                showOpenKeyboardPopup()
                return
            }
        }
        
        if emoji.length > 1 {
            let char2 = emoji.characterAtIndex(1)
            if char2 >= 57339 && char2 <= 57343
            { //is skin tone marker
                emoji = sender.text!.substringFromIndex(sender.text!.endIndex.predecessor().predecessor()) as NSString
            }
            
            if emoji.length % 4 == 0 && emoji.length > 4 { //flags stick together for some reason?
                emoji = emoji.substringFromIndex(emoji.length - 4)
            }
        }
        
        changeToEmoji(rawEmoji)
    }
    
    func changeToEmoji(emoji: String, animate: Bool = true) {
        copyCurrentEmojiToImageView()
        
        emojiLabel.text = emoji
        emojiNameLabel.text = nameForEmoji(emoji)
        
        let primaryColor = colorForImage(imageForEmoji(emoji))
        emojiView.backgroundColor = primaryColor
        let (text, border) = secondaryColorsForBackground(primaryColor)
        emojiNameLabel.textColor = text
        topBar.backgroundColor = border
        self.view.backgroundColor = primaryColor
        
        let backgroundLuma = colorLuma(border)
        let style = backgroundLuma > 0.28 ? UIStatusBarStyle.Default : UIStatusBarStyle.LightContent
        UIApplication.sharedApplication().setStatusBarStyle(style, animated: true)
        
        if animate { animateTransition() }
    }
    
    func nameForEmoji(emoji: String) -> String {
            
        let cfstring = NSMutableString(string: emoji) as CFMutableString
        var range = CFRangeMake(0, CFStringGetLength(cfstring))
        CFStringTransform(cfstring, &range, kCFStringTransformToUnicodeName, false)
        let capitalName = "\(cfstring)"
        
        if !capitalName.hasPrefix("\\") { //is number emoji
            var splits = capitalName.componentsSeparatedByString("\\")
            return ((capitalName as NSString).length > 1 ? "keycap " : "") + splits[0]
        }
            
        else {
            var splits = capitalName.componentsSeparatedByString("}")
            if splits.last == "" { splits.removeLast() }
            
            for i in 0 ..< splits.count {
                if (splits[i] as NSString).length > 3 {
                    splits[i] = (splits[i] as NSString).substringFromIndex(3).lowercaseString
                }
            }
            
            if splits.count == 1 {
                return splits[0]
            }
            
            if splits.count == 2{
                if splits[1].hasPrefix("emoji modifier") || splits[1].hasPrefix("variation selector"){ //skin tone emojis
                    return splits[0]
                }
                else { //flags are awful
                    var flagName = ""
                    for split in splits {
                        let splitNS = split.uppercaseString as NSString
                        flagName += splitNS.substringFromIndex(splitNS.length - 1)
                    }
                    
                    if let countryName = countryNameForCode(flagName){
                        flagName = countryName
                    }
                    
                    return flagName + " flag"
                }
            }
        }
        
        if emoji == "👁‍🗨" { return "eye in speech bubble" }
        //still nothing somehow
        return "family" //can only be family as far as I know
    }
    
    func imageForEmoji(emojiString: String) -> UIImage {
        let size = CGRectMake(0.0, 0.0, 100.0, 100.0)
        UIGraphicsBeginImageContext(size.size)
        let context = UIGraphicsGetCurrentContext()
        
        CGContextSetFillColorWithColor(context, UIColor.whiteColor().CGColor)
        CGContextFillRect(context, size)
        CGContextSetAllowsAntialiasing(context, true)
        CGContextSetShouldAntialias(context, true)
        
        let emoji = emojiString as NSString
        let font = UIFont.systemFontOfSize(75.0)
        let attributes = [NSFontAttributeName : font as AnyObject]
        let drawSize = emoji.boundingRectWithSize(size.size, options: .UsesLineFragmentOrigin, attributes: attributes, context: NSStringDrawingContext()).size
        
        let xOffset = (size.width - drawSize.width) / 2
        let yOffset = (size.height - drawSize.height) / 2
        let drawPoint = CGPointMake(xOffset, yOffset)
        let drawRect = CGRect(origin: drawPoint, size: drawSize)
        emoji.drawInRect(CGRectIntegral(drawRect), withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func colorForImage(uiimage: UIImage) -> UIColor {
        
        guard let image = uiimage.CGImage else { return UIColor.whiteColor() }
        let pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image))
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        typealias Pixel = (red: Int, green: Int, blue: Int)
        func pixelAtPoint(x: Int, _ y: Int) -> Pixel {
            let pixelIndex = ((Int(uiimage.size.width) * y) + x) * 4
            let b = Int(data[pixelIndex])
            let g = Int(data[pixelIndex + 1])
            let r = Int(data[pixelIndex + 2])
            return (r, g, b)
        }
        
        func clampInt(int: Int, onInterval interval: Int) -> Int {
            return Int(int / interval) * interval
        }
        
        var countMap: [String : (color: Pixel, count: Int)] = [:]
        var maximum: (color: Pixel, count: Int)?
        
        for y in 0 ..< Int(uiimage.size.width) {
            for x in 0 ..< Int(uiimage.size.height) {
                let pixel = pixelAtPoint(x, y)
                
                //ignore if this color is close to grayscale
                let average = (pixel.red + pixel.green + pixel.blue) / 3
                if abs(pixel.red - average) < 5
                    && abs(pixel.green - average) < 5
                    && abs(pixel.red - average) < 5 {
                        continue
                } 
                
                let red = clampInt(pixel.red, onInterval: 20)
                let green = clampInt(pixel.green, onInterval: 20)
                let blue = clampInt(pixel.blue, onInterval: 20)
                let key = "r:\(red) g:\(green) b:\(blue)"
                
                var (_, currentCount) = countMap[key] ?? ((0, 0, 0), 0)
                currentCount += 1
                countMap.updateValue((pixel, currentCount), forKey: key)
                
                if currentCount > maximum?.count {
                    maximum = (pixel, currentCount)
                }
            }
        }
        
        let color = maximum?.color ?? (red: 255, green: 255, blue: 255)
        return UIColor(red: CGFloat(color.red) / 255.0, green: CGFloat(color.green) / 255.0, blue: CGFloat(color.blue) / 255.0, alpha: 1.0)
    }
    
    func colorLuma(color: UIColor) -> CGFloat{
        var r : CGFloat  = 0.0
        var g : CGFloat  = 0.0
        var b : CGFloat  = 0.0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        let lumaR : CGFloat = CGFloat(r) * 0.3
        let lumaG : CGFloat = CGFloat(g) * 0.59
        let lumaB : CGFloat = CGFloat(b) * 0.11
        return (lumaR + lumaG + lumaB) / 3
    }
    
    func secondaryColorsForBackground(background: UIColor) -> (text: UIColor, border: UIColor) {
        
        var hue : CGFloat  = 0.0
        var sat : CGFloat  = 0.0
        var bright : CGFloat  = 0.0
        background.getHue(&hue, saturation: &sat, brightness: &bright, alpha: nil)
        let backgroundLuma = colorLuma(background)
        
        var text = UIColor(hue: hue, saturation: sat, brightness: bright + 0.35, alpha: 1.0)
        let textLuma = colorLuma(text)
        let lumaDiff = abs(textLuma - backgroundLuma)
        if lumaDiff < 0.05 && textLuma > 0.06 {
            text = UIColor(hue: hue, saturation: sat, brightness: bright - 0.35, alpha: 1.0)
        }
        
        let border = UIColor(hue: hue, saturation: sat, brightness: bright - 0.1, alpha: 1.0)
        
        return (text, border)
    }
    
    //MARK: - Transition between emoji
    
    func animateTransition() {
        let frame = emojiView.frame
        let diameter = min(frame.size.height, frame.size.width) * 2.0
        let internalFrame = CGRect(origin: CGPointMake(-self.view.frame.width / 2.0, -self.view.frame.height / 4.0), size: CGSizeMake(diameter, diameter))
        
        let circle = CALayer()
        circle.frame = internalFrame
        circle.cornerRadius = diameter / 2.0
        circle.backgroundColor = UIColor.blackColor().CGColor
        
        emojiView.layer.masksToBounds = true
        emojiView.layer.mask = circle
        
        //animate mask
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        
        circle.addAnimation(animation, forKey: "scale")
        
        //animate opacity real fast
        emojiView.alpha = 0.0
        UIView.animateWithDuration(0.15, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.emojiView.alpha = 1.0
        }, completion: nil)
        
        //animate scale
        emojiNameLabel.transform = CGAffineTransformMakeScale(0.01, 0.01)
        emojiNameLabel.alpha = 0.0
        emojiLabel.transform = CGAffineTransformMakeScale(0.01, 0.01)
        emojiLabel.alpha = 0.0
        
        UIView.animateWithDuration(0.6, delay: 0.05, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, options: [], animations: {
            self.emojiNameLabel.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.emojiNameLabel.alpha = 1.0
            self.emojiLabel.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.emojiLabel.alpha = 1.0
        }, completion: nil)
    }
    
    func copyCurrentEmojiToImageView() {
        UIGraphicsBeginImageContextWithOptions(emojiView.bounds.size, true, 0.0)
        emojiView.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        previousEmojiImage.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    //MARK: - ad delegate
    
    @IBOutlet weak var adBanner: ADBannerView!
    @IBOutlet weak var adPosition: NSLayoutConstraint!
    var keyboardHeight : CGFloat = 0
    var shouldShowAds = false
    
    func bannerViewDidLoadAd(banner: ADBannerView!) {
        
        if (!shouldShowAds) {
            self.updateContentHeight()
            adBanner.hidden = true
            return
        }
        
        if adPosition.constant != keyboardHeight {
            adPosition.constant = keyboardHeight
            UIView.animateWithDuration(0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                    self.view.layoutIfNeeded()
                }, completion: { success in
                    self.updateContentHeight()
            })
        }
        
    }
    
    func bannerView(banner: ADBannerView!, didFailToReceiveAdWithError error: NSError!) {
        adPosition.constant = -banner.frame.height
        UIView.animateWithDuration(0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: { self.view.layoutIfNeeded() }, completion: { success in
                self.updateContentHeight()
        })
    }
    
    func keyboardHidden(hidden: Bool) {
        adPosition.constant = (hidden ? -adBanner.frame.height : keyboardHeight)
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: { self.view.layoutIfNeeded() }, completion: nil)
    }
    
    func bannerViewActionShouldBegin(banner: ADBannerView!, willLeaveApplication willLeave: Bool) -> Bool {
        self.keyboardHidden(true)
        return true
    }
    
    func bannerViewActionDidFinish(banner: ADBannerView!) {
        self.adPosition.constant = -banner.frame.height
        self.view.layoutIfNeeded()
        self.hiddenField.becomeFirstResponder()
    }

}