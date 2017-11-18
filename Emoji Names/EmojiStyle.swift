//
//  EmojiStyle.swift
//  Emoji Names
//
//  Created by Cal Stephens on 11/17/17.
//  Copyright © 2017 Cal Stephens. All rights reserved.
//

import UIKit
import SVGKit

enum EmojiStyle: String, EnumType {
    
    case system
    case twitter
    
    // MARK: emoji -> UIImage
    
    func image(of emoji: String) -> UIImage {
        switch self {
        case .system:
            return generateImageWithSystemFont(for: emoji)
        case .twitter:
            return generateTwemojiImage(for: emoji) ?? generateImageWithSystemFont(for: emoji)
        }
    }
    
    private func generateTwemojiImage(
        for emoji: String,
        size: CGSize = CGSize(width: 100, height: 100)) -> UIImage?
    {
        guard let vector = loadTwemojiVector(for: emoji) else {
            return nil
        }
        
        vector.size = size
        return vector.uiImage
    }
    
    private func loadTwemojiVector(
        for emoji: String,
        ignoringVariationSelectors: Bool = false) -> SVGKImage?
    {
        let codepointStrings = emoji.unicodeScalars.flatMap { scalar -> String? in
            let codepoint = scalar.value
            let hexString = String(format: "%x", codepoint)
            
            if ignoringVariationSelectors {
                // twemoji sometimes excludes fe0f (uniode variation selector 16)
                guard hexString != "fe0f" else {
                    return nil
                }
            }
            
            return hexString
        }
        
        let expectedVectorName = codepointStrings.joined(separator: "-")
        
        guard let svgFilePath = Bundle.main.path(forResource: expectedVectorName, ofType: "svg"),
            let svgXml = try? String(contentsOf: URL(fileURLWithPath: svgFilePath)) else
        {
            //some twemoji include the variation selector, some don't
            if !ignoringVariationSelectors {
                return loadTwemojiVector(for: emoji, ignoringVariationSelectors: true)
            } else {
                return nil
            }
        }
        
        // i think there's some bug in SVGKit --
        // it was clipping the images to 36x36 instead of the full 45x45
        let correctedXml = svgXml.replacingOccurrences(
            of: "d=\"M 0,36 36,36 36,0 0,0 0,36 Z\"",
            with: "d=\"M 0,45 45,45 45,0 0,0 0,45 Z\"")
        .replacingOccurrences(
            of: "d=\"M 0,0 36,0 36,36 0,36 0,0 Z\"",
            with: "d=\"M 0,0 45,0 45,45 0,45 0,0 Z\"")
        
        return SVGKImage(data: correctedXml.data(using: .utf8))
    }
    
    private func generateImageWithSystemFont(
        for emojiString: String,
        size: CGSize = CGSize(width: 100, height: 100)) -> UIImage
    {
        return renderImageInNewContext(size: size, renderContents: { _ in
            let emoji = emojiString as NSString
            let font = UIFont.systemFont(ofSize: 75.0)
            let drawSize = emoji.boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: [.font : font], context: NSStringDrawingContext()).size
            
            let xOffset = (size.width - drawSize.width) / 2
            let yOffset = (size.height - drawSize.height) / 2
            let drawPoint = CGPoint(x: xOffset, y: yOffset)
            let drawRect = CGRect(origin: drawPoint, size: drawSize)
            emoji.draw(in: drawRect.integral, withAttributes: [.font : font])
        })
    }
    
    private func renderImageInNewContext(size: CGSize, renderContents: (CGContext) -> ()) -> UIImage {
        let size = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(size.size)
        let context = UIGraphicsGetCurrentContext()!
        
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(size)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        
        renderContents(context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image!
    }
    
    // MARK: render emoji onto UILabel
    
    func showEmoji(_ emoji: String, in label: UILabel) {
        switch self {
        case .system:
            label.text = emoji
        case .twitter:
            showTwemojiImage(for: emoji, in: label)
        }
    }
    
    private func showTwemojiImage(for emoji: String, in label: UILabel) {
        let emojiDimension = label.font.pointSize
        let emojiSize = CGSize(width: emojiDimension, height: emojiDimension)
        
        guard let twemojiImage = generateTwemojiImage(for: emoji, size: emojiSize) else {
            EmojiStyle.system.showEmoji(emoji, in: label)
            return
        }
        
        let textAttachment = NSTextAttachment()
        textAttachment.image = twemojiImage
        label.attributedText = NSAttributedString(attachment: textAttachment)
        label.clipsToBounds = false
    }
    
}
