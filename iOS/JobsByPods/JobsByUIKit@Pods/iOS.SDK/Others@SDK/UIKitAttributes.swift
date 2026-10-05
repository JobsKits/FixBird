//
//  UIKitAttributes.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension AttributeContainer {
    // MARK: - UIKitAttributes
    @discardableResult
    @inlinable
    public func byFont(_ font: UIFont?) -> Self {
        var c = self
        c.uiKit.font = font
        return c
    }

    @discardableResult
    @inlinable
    public func byParagraphStyle(_ style: NSParagraphStyle?) -> Self {
        var c = self
        c.uiKit.paragraphStyle = style
        return c
    }

    @discardableResult
    @inlinable
    public func byForegroundColor(_ color: UIColor?) -> Self {
        var c = self
        c.uiKit.foregroundColor = color
        return c
    }

    @discardableResult
    @inlinable
    public func byBackgroundColor(_ color: UIColor?) -> Self {
        var c = self
        c.uiKit.backgroundColor = color
        return c
    }

    @discardableResult
    @inlinable
    public func byLigature(_ v: Int?) -> Self {
        var c = self
        c.uiKit.ligature = v
        return c
    }

    @discardableResult
    @inlinable
    public func byKern(_ v: CGFloat?) -> Self {
        var c = self
        c.uiKit.kern = v
        return c
    }
    /// tracking / kern 的区别：tracking 是 “字距建议值”(TextKit / AttributedString)
    @discardableResult
    @inlinable
    public func byTracking(_ v: CGFloat?) -> Self {
        var c = self
        c.uiKit.tracking = v
        return c
    }

    @discardableResult
    @inlinable
    public func byStrikethroughStyle(_ style: NSUnderlineStyle?) -> Self {
        var c = self
        c.uiKit.strikethroughStyle = style
        return c
    }

    @discardableResult
    @inlinable
    public func byUnderlineStyle(_ style: NSUnderlineStyle?) -> Self {
        var c = self
        c.uiKit.underlineStyle = style
        return c
    }

    @discardableResult
    @inlinable
    public func byStrokeColor(_ color: UIColor?) -> Self {
        var c = self
        c.uiKit.strokeColor = color
        return c
    }

    @discardableResult
    @inlinable
    public func byStrokeWidth(_ v: CGFloat?) -> Self {
        var c = self
        c.uiKit.strokeWidth = v
        return c
    }

    @discardableResult
    @inlinable
    public func byShadow(_ shadow: NSShadow?) -> Self {
        var c = self
        c.uiKit.shadow = shadow
        return c
    }
    /// 这个类型在 SDK 里通常是 String（NSAttributedString.Key.textEffect 的值）
    @discardableResult
    @inlinable
    public func byTextEffect(_ v: NSAttributedString.TextEffectStyle?) -> Self {
        var c = self
        c.uiKit.textEffect = v
        return c
    }

    @discardableResult
    @inlinable
    public func byBaselineOffset(_ v: CGFloat?) -> Self {
        var c = self
        c.uiKit.baselineOffset = v
        return c
    }

    @discardableResult
    @inlinable
    public func byUnderlineColor(_ color: UIColor?) -> Self {
        var c = self
        c.uiKit.underlineColor = color
        return c
    }

    @discardableResult
    @inlinable
    public func byStrikethroughColor(_ color: UIColor?) -> Self {
        var c = self
        c.uiKit.strikethroughColor = color
        return c
    }
    // MARK: - Attachment (watchOS unavailable)
    @available(watchOS, unavailable)
    @discardableResult
    @inlinable
    public func byAttachment(_ attachment: NSTextAttachment?) -> Self {
        var c = self
        c.uiKit.attachment = attachment
        return c
    }
    // MARK: - Obliqueness / Expansion (TextKit2 not supported，但 API 仍在)
    @available(iOS 15.0, *)
    @discardableResult
    @inlinable
    public func byObliqueness(_ v: CGFloat?) -> Self {
        var c = self
        c.uiKit.obliqueness = v
        return c
    }

    @available(iOS 15.0, *)
    @discardableResult
    @inlinable
    public func byExpansion(_ v: CGFloat?) -> Self {
        var c = self
        c.uiKit.expansion = v
        return c
    }
    // MARK: - TextItemTag (iOS17+, tvOS unavailable)
    /// 注意：这个类型在你的 SDK 里可能不是 String，按补全改（常见是 `UITextItemTag` 或类似）
    @available(iOS 17.0, *)
    @available(tvOS, unavailable)
    @discardableResult
    @inlinable
    public func byTextItemTag(_ tag: Any?) -> Self {
        var c = self
        // 如果你的 SDK 类型不是 Any?，把 Any? 改成真实类型即可
        c.uiKit.textItemTag = tag as! AttributeScopes.UIKitAttributes.TextItemTagAttribute.Value
        return c
    }
    // MARK: - AdaptiveImageGlyph (iOS18+ 等)
    /// 注意：这个类型在你的 SDK 里也可能不是 Any?，按补全改成真实类型即可
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @discardableResult
    @inlinable
    public func byAdaptiveImageGlyph(_ v: Any?) -> Self {
        var c = self
        c.uiKit.adaptiveImageGlyph = v as! AttributeScopes.UIKitAttributes.AdaptiveImageGlyphAttribute.Value
        return c
    }
    // MARK: - Generic patch
    @discardableResult
    @inlinable
    public func byUIKit(_ patch: (inout AttributeContainer) -> Void) -> Self {
        var c = self
        patch(&c)
        return c
    }
}
