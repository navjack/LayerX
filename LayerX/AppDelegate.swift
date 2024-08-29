//
//  AppDelegate.swift
//  LayerX
//
//  Created by Michael Chen on 2015/10/26.
//  Copyright © 2015年 Michael Chen. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

private let tabTagBase = 500

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	private let defaultSize = NSMakeSize(480, 320)
	private let resizeStep: CGFloat = 0.1
    private let dockMenu = createDockMenu()

	var allSpaces = false
	var locked = false
	var onTop = false

	weak var window: MCWIndow!
	weak var viewController: ViewController!
	var isLockIconHiddenWhileLocked = false {
		didSet { viewController.lockIconImageView.isHidden = window.isMovable || isLockIconHiddenWhileLocked }
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		if let window = NSApp.windows.first as? MCWIndow {
			window.fitsWithSize(defaultSize)
			window.collectionBehavior = [.managed, .moveToActiveSpace]
			self.window = window
		}
	}
}

fileprivate enum ArrowTag: Int {
	case up = 20
	case left = 21
	case right = 22
	case down = 23
}

// MARK: - Hotkeys

extension AppDelegate {

	private var originalSize: NSSize {
		viewController.imageSize ?? defaultSize
	}

	func resizeAspectFit(calculator: (_ original: CGFloat, _ current: CGFloat) -> CGFloat) {
		let originalSize = self.originalSize
		let width = calculator(originalSize.width, window.frame.size.width)
		let height = width / originalSize.width * originalSize.height

		if width > 0 {
			window.resizeTo(NSSize(width: width, height: height), animated: true)
		}
	}

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return dockMenu
    }

    fileprivate class func createDockMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Switch to Image 1", action: #selector(showTab(_:)), keyEquivalent: "1").tag = tabTagBase + 1
        return menu
    }

    func updateMenusForTab(_ tab: Int, exists: Bool) {
        if let windowMenu = getWindowMenu() {
            updateMenu(windowMenu, tab: tab, exists: exists)
        }
        updateMenu(dockMenu, tab: tab, exists: exists)
    }

    fileprivate func getWindowMenu() -> NSMenu? {
        return NSApp.mainMenu?.item(withTag: 5)?.submenu
    }

    fileprivate func updateMenu(_ menu: NSMenu, tab: Int, exists: Bool) {
        let tag = tabTagBase + tab
        if !exists, let item = menu.item(withTag: tag) {
            if tab > 1 {
                menu.removeItem(item)
            }
        } else if exists, menu.item(withTag: tag) == nil {
            let prevIndex = menu.items.lastIndex { item in
                item.tag >= tabTagBase && item.tag < tag
            }!
            let item = menu.insertItem(withTitle: "Switch to Image \(tab)", action: #selector(self.showTab(_:)), keyEquivalent: String(tab), at: prevIndex + 1)
            item.tag = tag
            item.isEnabled = true
        }
    }

    @IBAction func newDocument(_ sender: AnyObject?) {
        if let tab = findNextUnusedTab() {
            viewController.selectTab(tab)
        }
    }

    fileprivate func findNextUnusedTab() -> Int? {
        for tab in 1...9 {
            if !viewController.tabHasImage(tab) {
                return tab
            }
        }
        return nil
    }

    @IBAction func openDocument(_ sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an image"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = true
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [UTType.image]
        } else {
            openPanel.allowedFileTypes = NSImage.imageTypes
        }
        openPanel.begin(completionHandler: { result in
            if result != .OK {
                return
            }
            for (index, url) in openPanel.urls.enumerated() {
                if let tab = index == 0 ? self.viewController.currentTab : self.findNextUnusedTab() {
                    if let image = NSImage(contentsOf: url) {
                        self.viewController.selectTab(tab)
                        self.viewController.updateCurrentImage(image)
                        self.updateMenusForTab(tab, exists: true)
                    }
                } else {
                    break
                }
            }
        })
    }

    @IBAction func performClose(_ sender: AnyObject?) {
        viewController.updateCurrentImage(nil)
        updateMenusForTab(viewController.currentTab, exists: false)
    }

	@IBAction func actualSize(_ sender: AnyObject?) {
		window.resizeTo(originalSize, animated: true)
	}

	@IBAction func makeLarger(_ sender: AnyObject) {
		resizeAspectFit { $0 * ($1 / $0 + resizeStep) }
	}

	@IBAction func makeSmaller(_ sender: AnyObject) {
		resizeAspectFit { $0 * ($1 / $0 - resizeStep) }
	}

	@IBAction func makeLargerOnePixel(_ sender: AnyObject) {
		resizeAspectFit { $1 + 1 }
	}

	@IBAction func makeSmallerOnePixel(_ sender: AnyObject) {
		resizeAspectFit { $1 - 1 }
	}

	@IBAction func increaseTransparency(_ sender: AnyObject) {
		viewController.changeTransparency(by: -0.1)
	}

	@IBAction func reduceTransparency(_ sender: AnyObject) {
		viewController.changeTransparency(by: 0.1)
	}
	
    @IBAction func showTab(_ sender: AnyObject) {
        let menuItem = sender as! NSMenuItem
        let tab = menuItem.tag - tabTagBase
        viewController.selectTab(tab)
    }

	func getPasteboardImage() -> NSImage? {
		let pasteboard = NSPasteboard.general;
		if let file = pasteboard.data(forType: NSPasteboard.PasteboardType.fileURL),
		   let str = String(data: file, encoding: .utf8),
		   let url = URL(string: str)
		{
			return NSImage(contentsOf: url)
		}

		if let tiff = pasteboard.data(forType: NSPasteboard.PasteboardType.tiff) {
			return NSImage(data: tiff)
		}

		if let png = pasteboard.data(forType: NSPasteboard.PasteboardType.png) {
			return NSImage(data: png)
		}

		return nil
	}

	@IBAction func paste(_ sender: AnyObject) {
		guard let image = getPasteboardImage() else { return }
		viewController.updateCurrentImage(image)
        updateMenusForTab(viewController.currentTab, exists: true)
	}
	
	@IBAction func toggleLockWindow(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		locked = !locked
		onTop = locked
		if locked {
			menuItem.title  = "Unlock"
			window.isMovable = false
			window.ignoresMouseEvents = true
			window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
		} else {
			menuItem.title  = "Lock"
			window.isMovable = true
			window.ignoresMouseEvents = false
			window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)))
		}

		viewController.lockIconImageView.isHidden = window.isMovable || isLockIconHiddenWhileLocked
	}
	
	@IBAction func toggleOnTop(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		onTop = !onTop
		if onTop {
			menuItem.title = "Don't keep on top"
			window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
		} else if !locked {
			menuItem.title = "Keep on top"
			window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)))
		}
	}
	
	@IBAction func toggleLockIconVisibility(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		menuItem.state = menuItem.state == .on ? .off : .on
		isLockIconHiddenWhileLocked = menuItem.state == .on
	}

	@IBAction func toggleSizeVisibility(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		menuItem.state = menuItem.state == .on ? .off : .on
		viewController.isSizeHidden = menuItem.state == .on
	}

	@IBAction func moveAround(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem

		guard let arrow = ArrowTag(rawValue: menuItem.tag) else {
			return
		}

		switch arrow {
		case .up:
			window.moveBy(CGPoint(x: 0, y: 1))
		case .left:
			window.moveBy(CGPoint(x: -1, y: 0))
		case .right:
			window.moveBy(CGPoint(x: 1, y: 0))
		case .down:
			window.moveBy(CGPoint(x: 0, y: -1))
		}
	}

	@IBAction func toggleAllSpaces(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		allSpaces = !allSpaces
		if allSpaces {
			menuItem.title = "Keep on this space"
			window.collectionBehavior = [.canJoinAllSpaces]
		} else {
			menuItem.title = "Keep on all spaces"
			window.collectionBehavior = [.managed, .moveToActiveSpace]
		}
	}
}

// MARK: - Helper

func appDelegate() -> AppDelegate {
	return NSApp.delegate as! AppDelegate
}
