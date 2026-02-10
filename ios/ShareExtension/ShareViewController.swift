import UIKit

@available(swift, introduced: 5.0)
open class ShareViewController: UIViewController {
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
