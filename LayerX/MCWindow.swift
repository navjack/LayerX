//
//  MCWindow.swift
//  LayerX
//
//  Created by Michael Chen on 2015/10/27.
//  Copyright © 2015年 Michael Chen. All rights reserved.
//

import Cocoa

class MCWIndow: NSWindow {
	override func awakeFromNib() {
		styleMask = [.borderless, .resizable]
		isOpaque = false
		backgroundColor = NSColor.clear
		isMovableByWindowBackground = true
		hasShadow = false
	}

    func moveBy(_ offset: CGPoint) {
        var frame = self.frame
        frame.origin.x += offset.x
        frame.origin.y += offset.y

        setFrame(frame, display: true)
    }

	func fitsWithSize(_ size: NSSize) {
		var frame = self.frame
		if frame.size.width < size.width || frame.size.height < size.height {
			frame.size = size
			setFrame(frame, display: true)
		}
	}

	func resizeTo(_ size: NSSize, animated: Bool) {
		let frame = self.resizeFrameTo(size)

		if !animated {
			setFrame(frame, display: true)
			return
		}

		let resizeAnimation = [NSViewAnimation.Key.target: self, NSViewAnimation.Key.endFrame: NSValue(rect: frame)]
		let animations = NSViewAnimation(viewAnimations: [resizeAnimation])
		animations.animationBlockingMode = .blocking
		animations.animationCurve = .easeInOut
		animations.duration = 0.15
		animations.start()
	}

    func resizeFrameTo(_ size: NSSize) -> NSRect {
        var frame = self.frame

        if let screen = NSScreen.main {
            // Resize from the top, left, bottom or right depending on how close to each edge the window is
            let fromLeft = (frame.origin.x + (frame.size.width / 2)) < (screen.frame.size.width / 2)
            let fromBottom = (frame.origin.y + (frame.size.height / 2)) < (screen.frame.size.height / 2)
            frame = frame.offsetBy(
                dx: fromLeft ? 0 : frame.size.width - size.width,
                dy: fromBottom ? 0 : frame.size.height - size.height)

            // Keep on screen
            if frame.origin.x + size.width > screen.frame.size.width {
                frame.origin.x = screen.frame.size.width - size.width
            }
            if frame.origin.y + size.height > screen.frame.size.height {
                frame.origin.y = screen.frame.size.height - size.height
            }
            frame = frame.offsetBy(dx: max(0, -frame.origin.x), dy: max(0, -frame.origin.y))
        }

        frame.size = size

        return frame
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
