import AppKit
import MyVibeIslandCore

public struct MyVibeIslandAppKitStatusItemMenuPresentationResult {
    public let descriptor: MyVibeIslandAppKitStatusMenuDescriptor
    public let menu: NSMenu?

    public init(
        descriptor: MyVibeIslandAppKitStatusMenuDescriptor,
        menu: NSMenu?
    ) {
        self.descriptor = descriptor
        self.menu = menu
    }
}

@MainActor
public final class MyVibeIslandAppKitStatusItemMenuPresenter {
    public let adapter: MyVibeIslandAppKitStatusMenuAdapter
    public let commandRouter: MyVibeIslandAppKitStatusMenuCommandRouter
    public let factory: MyVibeIslandAppKitStatusMenuFactory
    public let installMenu: (NSMenu?) -> Void
    public private(set) var lastResult: MyVibeIslandAppKitStatusItemMenuPresentationResult?

    public init(
        adapter: MyVibeIslandAppKitStatusMenuAdapter = MyVibeIslandAppKitStatusMenuAdapter(),
        dispatch: @escaping @MainActor (AppCommand) -> Void,
        installMenu: @escaping (NSMenu?) -> Void
    ) {
        self.adapter = adapter
        self.commandRouter = MyVibeIslandAppKitStatusMenuCommandRouter(dispatch: dispatch)
        self.factory = MyVibeIslandAppKitStatusMenuFactory(
            commandTarget: commandRouter,
            commandAction: #selector(MyVibeIslandAppKitStatusMenuCommandRouter.performStatusMenuCommand(_:))
        )
        self.installMenu = installMenu
    }

    public func apply(
        _ snapshot: StatusItemMenuSnapshot
    ) -> MyVibeIslandAppKitStatusItemMenuPresentationResult {
        let descriptor = adapter.makeMenuDescriptor(from: snapshot)
        let menu = factory.makeMenu(from: descriptor)
        installMenu(menu)
        let result = MyVibeIslandAppKitStatusItemMenuPresentationResult(
            descriptor: descriptor,
            menu: menu
        )
        lastResult = result
        return result
    }
}
