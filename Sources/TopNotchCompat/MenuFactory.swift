import AppKit
import TopNotchCompatCore

enum MenuFactory {
    static func gearMenu(target: AnyObject?, hideAction: Selector, websiteAction: Selector, quitAction: Selector) -> NSMenu {
        let menu = NSMenu()
        for entry in MenuSpec.topNotch {
            if entry.isSeparator {
                menu.addItem(.separator())
                continue
            }

            let action: Selector?
            switch entry.title {
            case "Hide Menubar Icon":
                action = hideAction
            case "Visit Website":
                action = websiteAction
            case "Quit":
                action = quitAction
            default:
                action = nil
            }

            let item = NSMenuItem(
                title: entry.title,
                action: action,
                keyEquivalent: entry.keyEquivalent
            )
            item.isEnabled = entry.isEnabled
            item.target = target
            menu.addItem(item)
        }
        return menu
    }
}
